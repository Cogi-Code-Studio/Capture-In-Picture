//
//  WindowCaptureService.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit
import UniformTypeIdentifiers

enum WindowCaptureError: LocalizedError {
    case permissionDenied
    case accessibilityPermissionDenied
    case noWindowsAvailable
    case saveCancelled
    case imageEncodingFailed
    case invalidCaptureInsets
    case invalidWindowSize
    case windowResizeUnavailable
    case windowResizeFailed
    case targetApplicationUnavailable
    case keyboardEventCreationFailed
    case invalidAutomationCount

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required to list and capture other apps."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to focus another app and send Right Arrow."
        case .noWindowsAvailable:
            return "There are no capturable windows right now."
        case .saveCancelled:
            return "Saving was cancelled."
        case .imageEncodingFailed:
            return "The captured image could not be converted to PNG."
        case .invalidCaptureInsets:
            return "Inset values are too large for the selected window."
        case .invalidWindowSize:
            return "Window width and height must be at least 1."
        case .windowResizeUnavailable:
            return "The selected window cannot be resized."
        case .windowResizeFailed:
            return "The app could not resize the selected window."
        case .targetApplicationUnavailable:
            return "The selected app is no longer available for automation."
        case .keyboardEventCreationFailed:
            return "The app could not create the Right Arrow key event."
        case .invalidAutomationCount:
            return "Automation capture count must be at least 1."
        }
    }
}

@MainActor
final class WindowCaptureService {
    private let rightArrowKeyCode: CGKeyCode = 124
    private let axResizableAttribute = "AXResizable" as CFString

    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func fetchWindows() async throws -> [WindowInfo] {
        guard hasScreenRecordingPermission() else {
            throw WindowCaptureError.permissionDenied
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

        let windows = shareableContent.windows
            .filter { $0.windowLayer == 0 }
            .map(WindowInfo.init(window:))
            .sorted(by: sortWindows)

        guard !windows.isEmpty else {
            throw WindowCaptureError.noWindowsAvailable
        }

        return windows
    }

    func captureAndSave(
        window: WindowInfo,
        preferredFolderURL: URL?,
        cropInsets: CaptureInsets
    ) async throws -> CaptureOutput {
        let image = try await captureImage(for: window, cropInsets: cropInsets)
        let destinationURL = try resolveSingleCaptureDestinationURL(
            for: window,
            preferredFolderURL: preferredFolderURL
        )
        try save(image: image, to: destinationURL)
        return CaptureOutput(image: image, fileURL: destinationURL)
    }

    func runAutomation(
        window: WindowInfo,
        captureCount: Int,
        stepDelaySeconds: Double,
        preferredFolderURL: URL?,
        cropInsets: CaptureInsets
    ) async throws -> AutomationRunOutput {
        guard captureCount > 0 else {
            throw WindowCaptureError.invalidAutomationCount
        }

        guard hasScreenRecordingPermission() else {
            throw WindowCaptureError.permissionDenied
        }

        guard hasAccessibilityPermission() else {
            throw WindowCaptureError.accessibilityPermissionDenied
        }

        let delaySeconds = max(stepDelaySeconds, 0.1)
        let outputFolderURL = try createAutomationFolder(for: window, preferredFolderURL: preferredFolderURL)
        var savedFiles: [URL] = []
        var lastImage: NSImage?

        try Task.checkCancellation()
        try await focusTarget(window: window)
        try await sleep(seconds: delaySeconds)

        for index in 1...captureCount {
            try Task.checkCancellation()
            let image = try await captureImage(for: window, cropInsets: cropInsets)
            let destinationURL = outputFolderURL.appendingPathComponent(
                automationFileName(for: window, index: index),
                conformingTo: .png
            )

            try save(image: image, to: destinationURL)
            savedFiles.append(destinationURL)
            lastImage = image

            if index < captureCount {
                try Task.checkCancellation()
                try sendRightArrow(to: window)
                try await sleep(seconds: delaySeconds)
            }
        }

        return AutomationRunOutput(
            lastImage: lastImage,
            folderURL: outputFolderURL,
            fileURLs: savedFiles
        )
    }

    func resizeWindow(_ window: WindowInfo, to size: CGSize) async throws -> CGSize {
        guard size.width > 0, size.height > 0 else {
            throw WindowCaptureError.invalidWindowSize
        }

        guard hasAccessibilityPermission() else {
            throw WindowCaptureError.accessibilityPermissionDenied
        }

        try await focusTarget(window: window)

        guard
            let pid = window.processID,
            let axWindow = matchingAXWindow(for: window, pid: pid)
        else {
            throw WindowCaptureError.targetApplicationUnavailable
        }

        if let isResizable = copyBoolAttribute(axResizableAttribute, from: axWindow), !isResizable {
            throw WindowCaptureError.windowResizeUnavailable
        }

        var requestedSize = size
        guard let sizeValue = AXValueCreate(.cgSize, &requestedSize) else {
            throw WindowCaptureError.windowResizeFailed
        }

        let resizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        switch resizeResult {
        case .success:
            try await sleep(seconds: 0.15)
            return copyCGSizeAttribute(kAXSizeAttribute as CFString, from: axWindow) ?? requestedSize
        case .attributeUnsupported:
            throw WindowCaptureError.windowResizeUnavailable
        default:
            throw WindowCaptureError.windowResizeFailed
        }
    }

    private func captureImage(for window: WindowInfo, cropInsets: CaptureInsets) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window.rawWindow)
        let configuration = SCStreamConfiguration()
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let width = max(Int(filter.contentRect.width * scale), 1)
        let height = max(Int(filter.contentRect.height * scale), 1)

        configuration.width = width
        configuration.height = height
        configuration.scalesToFit = true
        configuration.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let croppedImage = try cropImage(cgImage, using: cropInsets, scale: scale)
        let croppedSize = CGSize(
            width: CGFloat(croppedImage.width) / scale,
            height: CGFloat(croppedImage.height) / scale
        )
        return NSImage(cgImage: croppedImage, size: croppedSize)
    }

    private func presentSavePanel(for window: WindowInfo, preferredFolderURL: URL?) throws -> URL {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.directoryURL = preferredFolderURL ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        panel.nameFieldStringValue = defaultFileName(for: window)

        guard panel.runModal() == .OK, let url = panel.url else {
            throw WindowCaptureError.saveCancelled
        }

        return url
    }

    private func resolveSingleCaptureDestinationURL(for window: WindowInfo, preferredFolderURL: URL?) throws -> URL {
        guard let preferredFolderURL else {
            return try presentSavePanel(for: window, preferredFolderURL: nil)
        }

        let fileName = defaultFileName(for: window)
        let destinationURL = preferredFolderURL.appendingPathComponent(fileName, conformingTo: .png)
        return uniqueFileURL(for: destinationURL)
    }

    private func save(image: NSImage, to url: URL) throws {
        guard
            let tiffRepresentation = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw WindowCaptureError.imageEncodingFailed
        }

        try data.write(to: url)
    }

    private func focusTarget(window: WindowInfo) async throws {
        guard
            let pid = window.processID,
            let runningApplication = NSRunningApplication(processIdentifier: pid)
        else {
            throw WindowCaptureError.targetApplicationUnavailable
        }

        runningApplication.activate(options: [.activateAllWindows])
        try await sleep(seconds: 0.25)

        guard let axWindow = matchingAXWindow(for: window, pid: pid) else {
            return
        }

        _ = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private func sendRightArrow(to window: WindowInfo) throws {
        guard let pid = window.processID else {
            throw WindowCaptureError.targetApplicationUnavailable
        }

        guard
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: rightArrowKeyCode, keyDown: true),
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: rightArrowKeyCode, keyDown: false)
        else {
            throw WindowCaptureError.keyboardEventCreationFailed
        }

        keyDownEvent.postToPid(pid)
        keyUpEvent.postToPid(pid)
    }

    private func matchingAXWindow(for window: WindowInfo, pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowValue: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowValue) == .success,
            let axWindows = windowValue as? [AXUIElement]
        else {
            return nil
        }

        let expectedTitle = window.rawWindow.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expectedFrame = window.rawWindow.frame

        return axWindows.first { axWindow in
            let axTitle = copyStringAttribute(kAXTitleAttribute as CFString, from: axWindow) ?? ""
            let frameMatches = copyFrame(from: axWindow).map { approximatelyEqual($0, expectedFrame) } ?? false

            if !expectedTitle.isEmpty, axTitle == expectedTitle {
                return true
            }

            return frameMatches
        } ?? axWindows.first
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let stringValue = value as? String
        else {
            return nil
        }

        return stringValue
    }

    private func copyBoolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let booleanValue = value as? Bool
        else {
            return nil
        }

        return booleanValue
    }

    private func copyFrame(from element: AXUIElement) -> CGRect? {
        guard
            let position = copyCGPointAttribute(kAXPositionAttribute as CFString, from: element),
            let size = copyCGSizeAttribute(kAXSizeAttribute as CFString, from: element)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func copyCGPointAttribute(_ attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let axValue = value,
            CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func copyCGSizeAttribute(_ attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let axValue = value,
            CFGetTypeID(axValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 4 &&
        abs(lhs.origin.y - rhs.origin.y) < 4 &&
        abs(lhs.size.width - rhs.size.width) < 4 &&
        abs(lhs.size.height - rhs.size.height) < 4
    }

    private func cropImage(_ image: CGImage, using insets: CaptureInsets, scale: CGFloat) throws -> CGImage {
        guard !insets.isZero else {
            return image
        }

        let leftInset = Int((insets.left * scale).rounded())
        let rightInset = Int((insets.right * scale).rounded())
        let topInset = Int((insets.top * scale).rounded())
        let bottomInset = Int((insets.bottom * scale).rounded())

        let croppedWidth = image.width - leftInset - rightInset
        let croppedHeight = image.height - topInset - bottomInset

        guard croppedWidth > 0, croppedHeight > 0 else {
            throw WindowCaptureError.invalidCaptureInsets
        }

        let cropRect = CGRect(
            x: leftInset,
            y: topInset,
            width: croppedWidth,
            height: croppedHeight
        )

        guard let croppedImage = image.cropping(to: cropRect) else {
            throw WindowCaptureError.invalidCaptureInsets
        }

        return croppedImage
    }

    private func createAutomationFolder(for window: WindowInfo, preferredFolderURL: URL?) throws -> URL {
        let baseDirectoryURL: URL

        if let preferredFolderURL {
            baseDirectoryURL = preferredFolderURL
        } else {
            let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            baseDirectoryURL = picturesURL.appendingPathComponent("CaptureInPicture", isDirectory: true)
        }

        let timestamp = DateFormatter.fileNameFormatter.string(from: .now)
        let folderName = "\(sanitize(window.appName))-\(timestamp)"
        let outputFolderURL = baseDirectoryURL.appendingPathComponent(folderName, isDirectory: true)

        try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
        return outputFolderURL
    }

    private func uniqueFileURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        let directoryURL = url.deletingLastPathComponent()
        let fileExtension = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        var counter = 2

        while true {
            let candidateName = "\(baseName)-\(counter)"
            let candidateURL = directoryURL.appendingPathComponent(candidateName).appendingPathExtension(fileExtension)

            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            counter += 1
        }
    }

    private func automationFileName(for window: WindowInfo, index: Int) -> String {
        let title = sanitize(window.title)
        return String(format: "%03d-%@.png", index, title)
    }

    private func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func defaultFileName(for window: WindowInfo) -> String {
        let timestamp = DateFormatter.fileNameFormatter.string(from: .now)
        let appName = sanitize(window.appName)
        let title = sanitize(window.title)
        return "\(appName)-\(title)-\(timestamp).png"
    }

    private func sanitize(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.nilIfEmpty ?? "window"
    }

    private func sortWindows(lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }

        if lhs.appName != rhs.appName {
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

struct CaptureOutput {
    let image: NSImage
    let fileURL: URL
}

struct AutomationRunOutput {
    let lastImage: NSImage?
    let folderURL: URL
    let fileURLs: [URL]
}

private extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}
