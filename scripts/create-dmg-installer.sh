#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Create a drag-and-drop macOS installer DMG.

Usage:
  scripts/create-dmg-installer.sh <app-path> <dmg-path> <volume-name>
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

cleanup() {
  if [[ -n "${DEVICE:-}" ]]; then
    hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
  fi

  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

require_command hdiutil
require_command osascript
require_command plutil
require_command ruby
require_command swift

APP_PATH="$1"
DMG_PATH="$2"
VOLUME_NAME="$3"

[[ -d "$APP_PATH" ]] || die "App bundle not found at $APP_PATH"

APP_BASENAME="$(basename "$APP_PATH")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capture-in-picture-dmg.XXXXXX")"
STAGING_DIR="$TEMP_DIR/staging"
RW_DMG_PATH="$TEMP_DIR/installer-rw.dmg"
ATTACH_PLIST="$TEMP_DIR/attach.plist"
DEVICE=""

trap cleanup EXIT

rm -f "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"

swift - "$STAGING_DIR/.background/background.png" <<'SWIFT'
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 580, height: 330)
let image = NSImage(size: size)

image.lockFocus()

NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let arrowColor = NSColor(calibratedWhite: 0.55, alpha: 0.65)
arrowColor.setStroke()

let arrow = NSBezierPath()
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.lineWidth = 7
arrow.move(to: NSPoint(x: 238, y: 176))
arrow.line(to: NSPoint(x: 342, y: 176))
arrow.stroke()

arrowColor.setFill()
let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 352, y: 176))
arrowHead.line(to: NSPoint(x: 326, y: 194))
arrowHead.line(to: NSPoint(x: 326, y: 158))
arrowHead.close()
arrowHead.fill()

let text = "Drag to install" as NSString
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 18, weight: .medium),
  .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 0.8),
  .paragraphStyle: paragraphStyle
]
text.draw(
  in: NSRect(x: 0, y: 58, width: size.width, height: 26),
  withAttributes: attributes
)

image.unlockFocus()

guard
  let tiffData = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiffData),
  let pngData = bitmap.representation(using: .png, properties: [:])
else {
  FileHandle.standardError.write(Data("Unable to render DMG background image.\n".utf8))
  exit(1)
}

try pngData.write(to: outputURL)
SWIFT

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_DMG_PATH"

hdiutil attach "$RW_DMG_PATH" \
  -readwrite \
  -noverify \
  -noautoopen \
  -plist \
  > "$ATTACH_PLIST"

MOUNT_POINT="$(plutil -convert json -o - "$ATTACH_PLIST" | ruby -rjson -e 'data = JSON.parse(STDIN.read); entity = data.fetch("system-entities").find { |item| item["mount-point"] }; print entity && entity["mount-point"].to_s')"
DEVICE="$(plutil -convert json -o - "$ATTACH_PLIST" | ruby -rjson -e 'data = JSON.parse(STDIN.read); entity = data.fetch("system-entities").find { |item| item["mount-point"] }; print entity && entity["dev-entry"].to_s')"

[[ -n "$MOUNT_POINT" ]] || die "Unable to resolve mounted DMG path."
[[ -n "$DEVICE" ]] || die "Unable to resolve mounted DMG device."

osascript <<EOF
on run
  tell application "Finder"
    tell disk "$VOLUME_NAME"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {100, 100, 680, 430}
      set theViewOptions to icon view options of container window
      set arrangement of theViewOptions to not arranged
      set icon size of theViewOptions to 96
      set background picture of theViewOptions to file ".background:background.png"
      set position of item "$APP_BASENAME" of container window to {170, 165}
      set position of item "Applications" of container window to {410, 165}
      update without registering applications
      delay 1
      close
    end tell
  end tell
end run
EOF

sync
hdiutil detach "$DEVICE" >/dev/null
DEVICE=""

hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"
