[한국어](README.ko.md) | [English](README.md)

# Capture In Picture

Capture In Picture is a macOS app for capturing a specific app window as a PNG, with tools for repeatable documentation and screen recording workflows.

It is built for tutorial writers and anyone who needs repeatable window captures, and it works on `macOS 26.2 or later`.

![Capture In Picture dashboard](docs/screenshots/dashboard.png)

- [Features](#features)
- [Screenshots](#screenshots)
- [Install](#install)
- [Usage](#usage)
- [FAQ](#faq)
- [Privacy](#privacy)
- [Support](#support)
- [License](#license)

## Features

- Capture a specific app window instead of your entire screen.
- Resize the selected window before capture to keep output consistent.
- Build repeat capture flows with arrow keys, wait steps, and capture steps.
- Save one-shot captures immediately and run repeat capture sessions for multi-frame workflows.
- Trim the captured image with capture insets before saving.
- Choose a custom save folder, or use the default `Pictures/CaptureInPicture` location.
- Show local completion notifications without uploading captured images anywhere.
- Free and open source.

## Screenshots

| Dashboard | General Settings |
| --- | --- |
| ![Dashboard](docs/screenshots/dashboard.png) | ![General Settings](docs/screenshots/settings-general.png) |

| Capture Settings | Macro Builder |
| --- | --- |
| ![Capture Settings](docs/screenshots/settings-capture.png) | ![Macro Builder](docs/screenshots/settings-macro.png) |

## Install

- DMG: Download the latest build from [GitHub Releases](https://github.com/Cogi-Code-Studio/Capture-In-Picture/releases).
- App Store: Visit the [product page](https://studio.cogicode.com/products/capture-in-picture) for the latest availability.
- Source: Open `CaptureInPicture.xcodeproj` in Xcode and run the app on `macOS 26.2 or later`.

## Usage

1. Launch the app and grant `Screen Recording` permission.
2. Grant `Accessibility` permission if you want to resize windows or run repeat capture macros.
3. Pick the window you want to capture from the dashboard.
4. Optionally set the target window size before capture.
5. Run **Try One Capture** to confirm framing, crop, and output size.
6. Open **Settings** to adjust capture insets, save location, and macro flow.
7. Start **Repeat Capture** when you need multiple captures from the same workflow.

Global shortcuts for repeat capture:

- Start: `Control + Option + Command + S`
- Stop: `Control + Option + Command + X`

## Local Release Packaging

If you want to build a notarized DMG locally before uploading it to GitHub Releases, use:

```bash
APP_STORE_CONNECT_KEY_ID=your_key_id \
APP_STORE_CONNECT_ISSUER_ID=your_issuer_id \
APP_STORE_CONNECT_PRIVATE_KEY_FILE=~/Keys/AuthKey_XXXXXX.p8 \
./scripts/release-dmg.sh --tag v1.0.0
```

To upload the generated DMG to an existing GitHub release tag:

```bash
./scripts/release-dmg.sh --tag v1.0.0 --upload
```

To build a signed DMG without notarization:

```bash
./scripts/release-dmg.sh --version 1.0.0 --skip-notarize
```

The script expects a `Developer ID Application` certificate in your login keychain. If multiple identities exist, pass `--identity` or set `DEVELOPER_ID_IDENTITY`.

## FAQ

### Why does the app need Screen Recording permission?

macOS requires Screen Recording permission to list available windows from other apps and capture them as images.

### Why does the app need Accessibility permission?

Accessibility permission is used only for features that interact with another app window, such as resizing the selected window, focusing it, or sending macro key input during repeat capture.

### Where are captures saved?

One-shot captures are saved to your selected folder. If you do not choose a custom folder, the app uses `Pictures/CaptureInPicture`. Repeat capture creates a timestamped subfolder inside the selected base folder.

### What is the Macro Builder for?

Macro Builder lets you assemble repeat capture flows with arrow key steps, wait steps, and capture steps, which is useful when documenting UI flows or recording the same sequence across multiple frames.

### Are captured images uploaded anywhere?

No. Captured screenshots stay on your Mac. The app does not require an account, and it does not upload your captured images to the developer.

## Privacy

- [Privacy Policy (English)](docs/privacy-policy.md)
- [개인정보 처리방침 (Korean)](docs/privacy-policy.ko.md)

## Support

- Website: [studio.cogicode.com/products/capture-in-picture](https://studio.cogicode.com/products/capture-in-picture)
- Email: [admin@cogicode.com](mailto:admin@cogicode.com)
- Issues: [GitHub Issues](https://github.com/Cogi-Code-Studio/Capture-In-Picture/issues)

## License

MIT. See [LICENSE](LICENSE).
