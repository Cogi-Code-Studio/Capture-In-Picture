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
    case automationMacroMissingCaptureStep

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is required to list and capture other apps."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to focus another app and send macro key input."
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
            return "The selected window did not accept the new size. Refresh the list and try again."
        case .targetApplicationUnavailable:
            return "The selected window could not be matched for automation. Refresh the list and select it again."
        case .keyboardEventCreationFailed:
            return "The app could not create the keyboard event for the macro step."
        case .invalidAutomationCount:
            return "Automation capture count must be at least 1."
        case .automationMacroMissingCaptureStep:
            return "Add at least one Capture step to the macro flow before starting repeat capture."
        }
    }
}

@MainActor
final class WindowCaptureService {
    private let axResizableAttribute = "AXResizable" as CFString
    private let windowMatchTolerance: CGFloat = 6
    private let resizeVerificationTolerance: CGFloat = 2

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
        macroSteps: [AutomationMacroStep],
        startWithCapture: Bool,
        preferredFolderURL: URL?,
        cropInsets: CaptureInsets
    ) async throws -> AutomationRunOutput {
        guard captureCount > 0 else {
            throw WindowCaptureError.invalidAutomationCount
        }

        guard macroSteps.contains(where: \.isCapture) else {
            throw WindowCaptureError.automationMacroMissingCaptureStep
        }

        guard hasScreenRecordingPermission() else {
            throw WindowCaptureError.permissionDenied
        }

        guard hasAccessibilityPermission() else {
            throw WindowCaptureError.accessibilityPermissionDenied
        }

        let outputFolderURL = try createAutomationFolder(for: window, preferredFolderURL: preferredFolderURL)
        var savedFiles: [URL] = []
        var lastImage: NSImage?
        var nextCaptureIndex = 1
        var shouldSkipFirstCaptureStep = false

        try Task.checkCancellation()
        try await focusTarget(window: window)

        if startWithCapture {
            let output = try await saveAutomationCapture(
                for: window,
                cropInsets: cropInsets,
                outputFolderURL: outputFolderURL,
                index: nextCaptureIndex
            )
            savedFiles.append(output.fileURL)
            lastImage = output.image
            nextCaptureIndex += 1
            shouldSkipFirstCaptureStep = true

            if savedFiles.count >= captureCount {
                return AutomationRunOutput(
                    lastImage: lastImage,
                    folderURL: outputFolderURL,
                    fileURLs: savedFiles
                )
            }
        }

        automationLoop: while savedFiles.count < captureCount {
            for step in macroSteps {
                try Task.checkCancellation()

                switch step.kind {
                case .capture:
                    if shouldSkipFirstCaptureStep {
                        shouldSkipFirstCaptureStep = false
                        continue
                    }

                    let output = try await saveAutomationCapture(
                        for: window,
                        cropInsets: cropInsets,
                        outputFolderURL: outputFolderURL,
                        index: nextCaptureIndex
                    )
                    savedFiles.append(output.fileURL)
                    lastImage = output.image
                    nextCaptureIndex += 1

                    if savedFiles.count >= captureCount {
                        break automationLoop
                    }
                case .wait:
                    try await sleep(seconds: step.resolvedWaitDuration)
                case .up, .down, .left, .right:
                    try sendDirectionalKey(step.kind, to: window)
                }
            }
        }

        return AutomationRunOutput(
            lastImage: lastImage,
            folderURL: outputFolderURL,
            fileURLs: savedFiles
        )
    }

    private func saveAutomationCapture(
        for window: WindowInfo,
        cropInsets: CaptureInsets,
        outputFolderURL: URL,
        index: Int
    ) async throws -> CaptureOutput {
        let image = try await captureImage(for: window, cropInsets: cropInsets)
        let destinationURL = outputFolderURL.appendingPathComponent(
            automationFileName(for: window, index: index),
            conformingTo: .png
        )

        try save(image: image, to: destinationURL)
        return CaptureOutput(image: image, fileURL: destinationURL)
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

        let originalSize = copyCGSizeAttribute(kAXSizeAttribute as CFString, from: axWindow)

        var requestedSize = size
        guard let sizeValue = AXValueCreate(.cgSize, &requestedSize) else {
            throw WindowCaptureError.windowResizeFailed
        }

        let resizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        switch resizeResult {
        case .success:
            try await sleep(seconds: 0.3)
            let appliedSize = copyCGSizeAttribute(kAXSizeAttribute as CFString, from: axWindow) ?? requestedSize

            if sizeMatches(appliedSize, requestedSize, tolerance: resizeVerificationTolerance) {
                return appliedSize
            }

            if let originalSize, sizeMatches(appliedSize, originalSize, tolerance: resizeVerificationTolerance) {
                throw WindowCaptureError.windowResizeFailed
            }

            return appliedSize
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
            throw WindowCaptureError.targetApplicationUnavailable
        }

        _ = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private func sendDirectionalKey(_ direction: AutomationMacroStep.Kind, to window: WindowInfo) throws {
        guard let pid = window.processID else {
            throw WindowCaptureError.targetApplicationUnavailable
        }

        let keyCode: CGKeyCode
        switch direction {
        case .up:
            keyCode = 126
        case .down:
            keyCode = 125
        case .left:
            keyCode = 123
        case .right:
            keyCode = 124
        case .wait, .capture:
            return
        }

        guard
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
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

        let scoredWindows = axWindows.compactMap { axWindow -> (AXUIElement, Int)? in
            let axTitle = copyStringAttribute(kAXTitleAttribute as CFString, from: axWindow) ?? ""
            let axFrame = copyFrame(from: axWindow)
            let titleMatches = !expectedTitle.isEmpty && axTitle == expectedTitle
            let frameMatches = axFrame.map { approximatelyEqual($0, expectedFrame, tolerance: windowMatchTolerance) } ?? false
            let originMatches = axFrame.map {
                pointApproximatelyEqual($0.origin, expectedFrame.origin, tolerance: windowMatchTolerance)
            } ?? false
            let sizeMatch = axFrame.map {
                sizeMatches($0.size, expectedFrame.size, tolerance: windowMatchTolerance)
            } ?? false

            var score = 0
            if titleMatches {
                score += 4
            }
            if frameMatches {
                score += 6
            } else {
                if originMatches {
                    score += 2
                }
                if sizeMatch {
                    score += 2
                }
            }

            guard score > 0 else {
                return nil
            }

            return (axWindow, score)
        }

        return scoredWindows
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return copyBoolAttribute(kAXMainAttribute as CFString, from: lhs.0) == true
                }

                return lhs.1 > rhs.1
            }
            .first?
            .0
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

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        pointApproximatelyEqual(lhs.origin, rhs.origin, tolerance: tolerance) &&
        sizeMatches(lhs.size, rhs.size, tolerance: tolerance)
    }

    private func pointApproximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, tolerance: CGFloat) -> Bool {
        abs(lhs.x - rhs.x) <= tolerance &&
        abs(lhs.y - rhs.y) <= tolerance
    }

    private func sizeMatches(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance &&
        abs(lhs.height - rhs.height) <= tolerance
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
