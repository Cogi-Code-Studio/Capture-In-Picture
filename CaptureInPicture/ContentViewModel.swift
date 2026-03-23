//
//  ContentViewModel.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import AppKit
import Carbon
import Combine
import Foundation
import ScreenCaptureKit
import UserNotifications

@MainActor
final class ContentViewModel: ObservableObject {
    private enum HotKeyID {
        static let startAutomation: UInt32 = 1
        static let stopAutomation: UInt32 = 2
    }

    @Published private(set) var windows: [WindowInfo] = []
    @Published var selectedWindowID: WindowInfo.ID? {
        didSet {
            syncWindowSizeInputsFromSelection()
        }
    }
    @Published private(set) var hasPermission = false
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var isLoading = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isResizingWindow = false
    @Published private(set) var isAutomating = false
    @Published private(set) var statusMessage = "Grant Screen Recording access, then refresh the list."
    @Published private(set) var statusColor = NSColor.secondaryLabelColor
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var lastAutomationFolderURL: URL?
    @Published private(set) var selectedSaveFolderURL: URL?
    @Published var automationCaptureCountText = "5"
    @Published var captureInsetTopText = "0"
    @Published var captureInsetLeftText = "0"
    @Published var captureInsetBottomText = "0"
    @Published var captureInsetRightText = "0"
    @Published var windowWidthText = ""
    @Published var windowHeightText = ""

    let automationStartShortcutDescription = "Control + Option + Command + S"
    let automationStopShortcutDescription = "Control + Option + Command + X"

    private let captureService: WindowCaptureService
    private let notificationManager: CaptureNotificationManager
    private let hotKeyManager: GlobalHotKeyManager
    private let saveFolderStore: SaveFolderStore
    private let automationStepDelaySeconds = 0.6
    private var automationTask: Task<Void, Never>?

    init(captureService: WindowCaptureService? = nil) {
        let resolvedCaptureService = captureService ?? WindowCaptureService()
        self.captureService = resolvedCaptureService
        notificationManager = CaptureNotificationManager()
        hotKeyManager = GlobalHotKeyManager()
        saveFolderStore = SaveFolderStore()
        refreshPermissions()
        restoreSavedFolder()
        restoreCaptureInsets()
        registerHotKeys()
    }

    var selectedWindow: WindowInfo? {
        windows.first(where: { $0.id == selectedWindowID })
    }

    func loadWindows() async {
        isLoading = true
        defer { isLoading = false }

        refreshPermissions()

        guard hasPermission else {
            windows = []
            selectedWindowID = nil
            setStatus(
                "Screen Recording permission is off. Use the button below to request access.",
                color: .systemOrange
            )
            return
        }

        do {
            let loadedWindows = try await captureService.fetchWindows()
            windows = loadedWindows

            if !loadedWindows.contains(where: { $0.id == selectedWindowID }) {
                selectedWindowID = loadedWindows.first?.id
            } else {
                syncWindowSizeInputsFromSelection()
            }

            setStatus("Select a window and press Capture Screenshot.", color: .systemGreen)
        } catch {
            windows = []
            selectedWindowID = nil
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func requestPermission() {
        hasPermission = captureService.requestScreenRecordingPermission()

        if hasPermission {
            setStatus("Permission granted. Refresh the list to load capturable windows.", color: .systemGreen)
        } else {
            setStatus(
                "If macOS did not grant access immediately, enable Screen Recording for this app in System Settings and reopen it.",
                color: .systemOrange
            )
        }
    }

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = captureService.requestAccessibilityPermission()

        if hasAccessibilityPermission {
            setStatus("Accessibility permission granted. Automation can now send Right Arrow.", color: .systemGreen)
        } else {
            setStatus(
                "If macOS did not grant access immediately, enable Accessibility for this app in System Settings.",
                color: .systemOrange
            )
        }
    }

    func openSystemSettings() {
        captureService.openScreenRecordingSettings()
    }

    func openAccessibilitySettings() {
        captureService.openAccessibilitySettings()
    }

    func captureSelectedWindow() async {
        guard let selectedWindow else {
            setStatus("Select a window first.", color: .systemOrange)
            return
        }

        let cropInsets = normalizedCaptureInsets()

        isCapturing = true
        defer { isCapturing = false }

        do {
            let output = try await captureService.captureAndSave(
                window: selectedWindow,
                preferredFolderURL: selectedSaveFolderURL,
                cropInsets: cropInsets
            )
            previewImage = output.image
            lastSavedURL = output.fileURL
            setStatus("Saved screenshot to \(output.fileURL.lastPathComponent)", color: .systemGreen)
            await notificationManager.postOneCaptureCompleted(fileURL: output.fileURL)
        } catch WindowCaptureError.saveCancelled {
            setStatus("Save cancelled.", color: .secondaryLabelColor)
        } catch {
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func normalizeAutomationCaptureCount() {
        guard let count = parsedAutomationCaptureCount else {
            automationCaptureCountText = "5"
            return
        }

        automationCaptureCountText = "\(count)"
    }

    func normalizeCaptureInsets() {
        _ = normalizedCaptureInsets()
    }

    func normalizeWindowSize() {
        guard let windowSize = parsedWindowSize else {
            syncWindowSizeInputsFromSelection()
            return
        }

        applyWindowSizeInputs(windowSize)
    }

    func resetCaptureInsets() {
        applyCaptureInsets(.zero)
        setStatus("Inset values reset to 0 pt.", color: .secondaryLabelColor)
    }

    func useSelectedWindowSize() {
        guard let selectedWindow else {
            windowWidthText = ""
            windowHeightText = ""
            setStatus("Select a window first.", color: .systemOrange)
            return
        }

        applyWindowSizeInputs(selectedWindow.rawWindow.frame.size)
        setStatus("Loaded the selected window size.", color: .secondaryLabelColor)
    }

    func resizeSelectedWindow() async {
        guard let selectedWindow else {
            setStatus("Select a window first.", color: .systemOrange)
            return
        }

        refreshPermissions()

        guard hasAccessibilityPermission else {
            setStatus("Accessibility permission is required to resize another app window.", color: .systemOrange)
            return
        }

        guard let windowSize = parsedWindowSize else {
            setStatus("Enter a valid width and height first.", color: .systemOrange)
            return
        }

        applyWindowSizeInputs(windowSize)
        isResizingWindow = true
        defer { isResizingWindow = false }

        do {
            let appliedSize = try await captureService.resizeWindow(selectedWindow, to: windowSize)
            await loadWindows()
            setStatus(
                "Resized window to \(Int(appliedSize.width)) x \(Int(appliedSize.height)).",
                color: .systemGreen
            )
        } catch {
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func startAutomationFromHotKey() {
        guard automationTask == nil else {
            setStatus("Automation is already running.", color: .systemOrange)
            return
        }

        guard let captureCount = parsedAutomationCaptureCount else {
            setStatus("Enter a valid repeat count first.", color: .systemOrange)
            return
        }

        let cropInsets = normalizedCaptureInsets()
        automationCaptureCountText = "\(captureCount)"

        automationTask = Task { [weak self] in
            await self?.runAutomation(captureCount: captureCount, cropInsets: cropInsets)
        }
    }

    func startAutomation() {
        startAutomationFromHotKey()
    }

    func stopAutomation() {
        guard let automationTask else {
            setStatus("No automation is running.", color: .secondaryLabelColor)
            return
        }

        automationTask.cancel()
        setStatus("Stopping automation...", color: .systemOrange)
    }

    private func runAutomation(captureCount: Int, cropInsets: CaptureInsets) async {
        guard let selectedWindow else {
            setStatus("Select a window first.", color: .systemOrange)
            automationTask = nil
            return
        }

        isAutomating = true
        defer {
            isAutomating = false
            automationTask = nil
        }

        refreshPermissions()

        guard hasPermission else {
            setStatus(WindowCaptureError.permissionDenied.localizedDescription, color: .systemOrange)
            return
        }

        guard hasAccessibilityPermission else {
            setStatus(WindowCaptureError.accessibilityPermissionDenied.localizedDescription, color: .systemOrange)
            return
        }

        await notificationManager.postRepeatCaptureStarted(windowTitle: selectedWindow.title, captureCount: captureCount)

        do {
            let output = try await captureService.runAutomation(
                window: selectedWindow,
                captureCount: captureCount,
                stepDelaySeconds: automationStepDelaySeconds,
                preferredFolderURL: selectedSaveFolderURL,
                cropInsets: cropInsets
            )

            previewImage = output.lastImage
            lastSavedURL = output.fileURLs.last
            lastAutomationFolderURL = output.folderURL
            setStatus(
                "Auto capture finished: \(output.fileURLs.count) images saved to \(output.folderURL.lastPathComponent).",
                color: .systemGreen
            )
            await notificationManager.postRepeatCaptureCompleted(
                folderURL: output.folderURL,
                imageCount: output.fileURLs.count
            )
        } catch is CancellationError {
            setStatus("Automation stopped.", color: .secondaryLabelColor)
        } catch {
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func revealLastSavedCapture() {
        guard let lastSavedURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }

    func chooseSaveFolder() {
        do {
            let folderURL = try saveFolderStore.chooseFolder()
            selectedSaveFolderURL = folderURL
            setStatus("Save folder set to \(folderURL.lastPathComponent).", color: .systemGreen)
        } catch SaveFolderError.folderSelectionCancelled {
            setStatus("Folder selection cancelled.", color: .secondaryLabelColor)
        } catch {
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func clearSaveFolder() {
        saveFolderStore.clearFolder()
        selectedSaveFolderURL = nil
        setStatus("Save folder reset to the default location.", color: .secondaryLabelColor)
    }

    func openSelectedSaveFolder() {
        guard let selectedSaveFolderURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([selectedSaveFolderURL])
    }

    func copySaveLocationToClipboard() {
        let resolvedPath = resolvedSaveLocationURL.path
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if pasteboard.setString(resolvedPath, forType: .string) {
            setStatus("Copied save location to clipboard: \(resolvedPath)", color: .systemGreen)
        } else {
            setStatus("Could not copy the save location to the clipboard.", color: .systemRed)
        }
    }

    private func refreshPermissions() {
        hasPermission = captureService.hasScreenRecordingPermission()
        hasAccessibilityPermission = captureService.hasAccessibilityPermission()
    }

    private func restoreSavedFolder() {
        do {
            selectedSaveFolderURL = try saveFolderStore.restoreFolder()
        } catch {
            selectedSaveFolderURL = nil
            setStatus(error.localizedDescription, color: .systemOrange)
        }
    }

    private func restoreCaptureInsets() {
        let captureInsets = CaptureInsets(
            top: CGFloat(UserDefaults.standard.integer(forKey: "captureInsetTop")),
            left: CGFloat(UserDefaults.standard.integer(forKey: "captureInsetLeft")),
            bottom: CGFloat(UserDefaults.standard.integer(forKey: "captureInsetBottom")),
            right: CGFloat(UserDefaults.standard.integer(forKey: "captureInsetRight"))
        )
        applyCaptureInsets(captureInsets)
    }

    private func registerHotKeys() {
        let modifiers = UInt32(controlKey | optionKey | cmdKey)

        hotKeyManager.register(
            id: HotKeyID.startAutomation,
            keyCode: 1,
            modifiers: modifiers
        ) { [weak self] in
            self?.startAutomationFromHotKey()
        }

        hotKeyManager.register(
            id: HotKeyID.stopAutomation,
            keyCode: 7,
            modifiers: modifiers
        ) { [weak self] in
            self?.stopAutomation()
        }
    }

    private var parsedAutomationCaptureCount: Int? {
        let trimmed = automationCaptureCountText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let count = Int(trimmed), count > 0 else {
            return nil
        }

        return min(count, 10_000)
    }

    private func normalizedCaptureInsets() -> CaptureInsets {
        let captureInsets = CaptureInsets(
            top: CGFloat(normalizedInsetValue(from: captureInsetTopText)),
            left: CGFloat(normalizedInsetValue(from: captureInsetLeftText)),
            bottom: CGFloat(normalizedInsetValue(from: captureInsetBottomText)),
            right: CGFloat(normalizedInsetValue(from: captureInsetRightText))
        )
        applyCaptureInsets(captureInsets)
        return captureInsets
    }

    private func normalizedInsetValue(from text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Int(trimmed), value >= 0 else {
            return 0
        }

        return min(value, 10_000)
    }

    private var parsedWindowSize: CGSize? {
        guard
            let width = normalizedWindowDimensionValue(from: windowWidthText),
            let height = normalizedWindowDimensionValue(from: windowHeightText)
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    private func normalizedWindowDimensionValue(from text: String) -> CGFloat? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Int(trimmed), value > 0 else {
            return nil
        }

        return CGFloat(min(value, 10_000))
    }

    private func applyCaptureInsets(_ captureInsets: CaptureInsets) {
        captureInsetTopText = "\(Int(captureInsets.top))"
        captureInsetLeftText = "\(Int(captureInsets.left))"
        captureInsetBottomText = "\(Int(captureInsets.bottom))"
        captureInsetRightText = "\(Int(captureInsets.right))"

        UserDefaults.standard.set(Int(captureInsets.top), forKey: "captureInsetTop")
        UserDefaults.standard.set(Int(captureInsets.left), forKey: "captureInsetLeft")
        UserDefaults.standard.set(Int(captureInsets.bottom), forKey: "captureInsetBottom")
        UserDefaults.standard.set(Int(captureInsets.right), forKey: "captureInsetRight")
    }

    private func syncWindowSizeInputsFromSelection() {
        guard let selectedWindow else {
            windowWidthText = ""
            windowHeightText = ""
            return
        }

        applyWindowSizeInputs(selectedWindow.rawWindow.frame.size)
    }

    private func applyWindowSizeInputs(_ size: CGSize) {
        windowWidthText = "\(Int(size.width.rounded()))"
        windowHeightText = "\(Int(size.height.rounded()))"
    }

    private var resolvedSaveLocationURL: URL {
        if let selectedSaveFolderURL {
            return selectedSaveFolderURL
        }

        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return picturesURL.appendingPathComponent("CaptureInPicture", isDirectory: true)
    }

    private func setStatus(_ message: String, color: NSColor) {
        statusMessage = message
        statusColor = color
    }
}

private final class CaptureNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func postOneCaptureCompleted(fileURL: URL) async {
        await postNotification(
            title: "One Capture Complete",
            body: "\(fileURL.lastPathComponent) has been saved."
        )
    }

    func postRepeatCaptureStarted(windowTitle: String, captureCount: Int) async {
        let resolvedWindowTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "selected window"
            : windowTitle
        await postNotification(
            title: "Repeat Capture Started",
            body: "Capturing \(captureCount) frame(s) from \(resolvedWindowTitle)."
        )
    }

    func postRepeatCaptureCompleted(folderURL: URL, imageCount: Int) async {
        await postNotification(
            title: "Repeat Capture Complete",
            body: "\(imageCount) image(s) saved to \(folderURL.lastPathComponent)."
        )
    }

    private func postNotification(title: String, body: String) async {
        guard await ensureAuthorization() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await add(request)
        } catch {
            // Ignore notification delivery failures so capture flows still complete normally.
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await requestAuthorization()
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
