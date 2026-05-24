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

    enum PermissionOnboardingStep: Int, CaseIterable, Identifiable {
        case screenRecording
        case accessibility
        case notifications
        case ready

        var id: Int { rawValue }
    }

    enum NotificationPermissionState {
        case notDetermined
        case authorized
        case denied

        var isAuthorized: Bool {
            self == .authorized
        }
    }

    enum AppUpdateStatus: Equatable {
        case idle
        case checking
        case upToDate(latestVersion: String)
        case updateAvailable(latestVersion: String)
        case unavailable(reason: String)
    }

    private enum UserDefaultsKey {
        static let hasSeenPermissionOnboarding = "hasSeenPermissionOnboarding"
        static let hasAcknowledgedNotificationOnboarding = "hasAcknowledgedNotificationOnboarding"
        static let automationMacroSteps = "automationMacroSteps"
        static let automationStartWithCapture = "automationStartWithCapture"
    }

    @Published private(set) var selectedWindow: WindowInfo? {
        didSet {
            syncWindowSizeInputsFromSelection()
        }
    }
    @Published private(set) var hasPermission = false
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var notificationPermissionState: NotificationPermissionState = .notDetermined
    @Published private(set) var hasAcknowledgedNotificationOnboarding = false
    @Published private(set) var appUpdateStatus: AppUpdateStatus = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isChoosingWindow = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isResizingWindow = false
    @Published private(set) var isAutomating = false
    @Published private(set) var isShowingPermissionOnboarding = false
    @Published private(set) var activePermissionOnboardingStep: PermissionOnboardingStep = .screenRecording
    @Published private(set) var statusMessage = "Grant Screen Recording access, then choose a window."
    @Published private(set) var statusColor = NSColor.secondaryLabelColor
    @Published private(set) var targetPreviewImage: NSImage?
    @Published private(set) var isTargetPreviewActive = false
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var lastAutomationFolderURL: URL?
    @Published private(set) var selectedSaveFolderURL: URL?
    @Published var automationCaptureCountText = "5"
    @Published var macroSteps: [AutomationMacroStep] = []
    @Published var startWithCapture = false {
        didSet {
            persistStartWithCapturePreference()
        }
    }
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
    private let appSupportService: AppSupportService
    private var automationTask: Task<Void, Never>?
    private var targetPreviewID = UUID()

    init(captureService: WindowCaptureService? = nil, appSupportService: AppSupportService? = nil) {
        let resolvedCaptureService = captureService ?? WindowCaptureService()
        self.captureService = resolvedCaptureService
        notificationManager = CaptureNotificationManager()
        hotKeyManager = GlobalHotKeyManager()
        saveFolderStore = SaveFolderStore()
        self.appSupportService = appSupportService ?? AppSupportService()
        hasAcknowledgedNotificationOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKey.hasAcknowledgedNotificationOnboarding)
        refreshPermissions()
        isShowingPermissionOnboarding = shouldAutoPresentPermissionOnboarding()
        syncPermissionOnboardingStep()
        restoreSavedFolder()
        restoreCaptureInsets()
        restoreMacroSteps()
        restoreStartWithCapturePreference()
        registerHotKeys()

        Task { [weak self] in
            await self?.refreshNotificationPermissionState()
        }
    }

    var automationFlowSummary: String {
        let stepSummaries = macroSteps.map(\.shortSummary)

        if stepSummaries.isEmpty {
            return startWithCapture
                ? "Start Capture -> Add a Capture step in Settings > Macro."
                : "No macro steps yet. Add a Capture step in Settings > Macro."
        }

        let summaries = startWithCapture ? ["Start Capture"] + stepSummaries : stepSummaries
        return summaries.joined(separator: " -> ")
    }

    var automationMacroStepCountDescription: String {
        let stepCount = macroSteps.count
        let captureStepCount = macroSteps.filter(\.isCapture).count
        let stepLabel = stepCount == 1 ? "step" : "steps"
        let captureLabel = captureStepCount == 1 ? "capture node" : "capture nodes"
        let startCaptureDescription = startWithCapture ? " · starts with capture" : ""
        return "\(stepCount) \(stepLabel) · \(captureStepCount) \(captureLabel)\(startCaptureDescription)"
    }

    var captureInsetSummary: String {
        "T\(captureInsetTopText) B\(captureInsetBottomText) L\(captureInsetLeftText) R\(captureInsetRightText)"
    }

    var repeatCaptureSummary: String {
        automationCaptureCountText.isEmpty ? "0" : automationCaptureCountText
    }

    var saveLocationDisplayPath: String {
        (resolvedSaveLocationURL.path as NSString).abbreviatingWithTildeInPath
    }

    var shouldShowPermissionBanner: Bool {
        !isShowingPermissionOnboarding && (!hasPermission || !hasAccessibilityPermission)
    }

    var hasRequiredPermissions: Bool {
        hasPermission && hasAccessibilityPermission
    }

    var canDismissPermissionOnboarding: Bool {
        true
    }

    var shouldShowPermissionGate: Bool {
        false
    }

    var hasNotificationPermission: Bool {
        notificationPermissionState.isAuthorized
    }

    var installedAppVersion: String {
        appSupportService.installedVersion().versionDisplayName
    }

    var installedAppBuild: String {
        appSupportService.installedVersion().buildDisplayName
    }

    var supportEmailAddress: String {
        appSupportService.supportEmailAddress
    }

    var shouldShowNotificationOnboardingStep: Bool {
        !hasNotificationPermission && !hasAcknowledgedNotificationOnboarding
    }

    var permissionOnboardingSteps: [PermissionOnboardingStep] {
        var steps: [PermissionOnboardingStep] = []

        if !hasPermission {
            steps.append(.screenRecording)
        }

        if !hasAccessibilityPermission {
            steps.append(.accessibility)
        }

        if shouldShowNotificationOnboardingStep {
            steps.append(.notifications)
        }

        if steps.isEmpty {
            steps.append(.ready)
        }

        return steps
    }

    var permissionOnboardingStepIndex: Int {
        permissionOnboardingSteps.firstIndex(of: activePermissionOnboardingStep) ?? 0
    }

    var permissionOnboardingPageNumber: Int {
        permissionOnboardingStepIndex + 1
    }

    var pendingPermissionOnboardingSteps: [PermissionOnboardingStep] {
        guard permissionOnboardingStepIndex < permissionOnboardingSteps.count else {
            return []
        }

        return Array(permissionOnboardingSteps.dropFirst(permissionOnboardingStepIndex + 1))
    }

    func loadWindows() async {
        isLoading = true
        defer { isLoading = false }

        refreshPermissions()

        guard hasPermission else {
            selectedWindow = nil
            await stopTargetPreview()
            setStatus(
                "Screen Recording permission is off. Use the button below to request access.",
                color: .systemOrange
            )
            return
        }

        if let selectedWindow {
            do {
                let refreshedWindow = try await captureService.refreshWindow(selectedWindow)
                self.selectedWindow = refreshedWindow
                await startTargetPreview(for: refreshedWindow)
                setStatus("Selected \(selectedWindow.appName): \(selectedWindow.title)", color: .systemGreen)
            } catch {
                self.selectedWindow = nil
                await stopTargetPreview()
                setStatus("Choose a window to capture.", color: .secondaryLabelColor)
            }
        } else {
            await stopTargetPreview()
            setStatus("Choose a window to capture.", color: .secondaryLabelColor)
        }
    }

    func requestPermission() {
        hasPermission = captureService.requestScreenRecordingPermission()
        syncPermissionOnboardingStep()

        if hasPermission {
            setStatus("Permission granted. Choose a window to capture.", color: .systemGreen)
        } else {
            setStatus(
                "If macOS did not grant access immediately, enable Screen Recording for this app in System Settings and reopen it.",
                color: .systemOrange
            )
        }
    }

    func requestAccessibilityPermission() {
        hasAccessibilityPermission = captureService.requestAccessibilityPermission()
        syncPermissionOnboardingStep()

        if hasAccessibilityPermission {
            setStatus("Accessibility permission granted. Automation can now control the selected app window.", color: .systemGreen)
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

    func openNotificationSettings() {
        captureService.openNotificationSettings()
    }

    func requestNotificationPermission() async {
        notificationPermissionState = await notificationManager.requestAuthorizationIfNeeded()

        switch notificationPermissionState {
        case .authorized:
            acknowledgeNotificationOnboarding()
            setStatus("Notification permission granted. Capture completion alerts can now appear without interrupting capture.", color: .systemGreen)
        case .denied:
            setStatus("Notification permission is off. You can still capture normally, or enable notifications later in System Settings.", color: .systemOrange)
        case .notDetermined:
            setStatus("Notification permission has not been decided yet.", color: .secondaryLabelColor)
        }

        syncPermissionOnboardingStep()
    }

    func skipNotificationOnboardingStep() {
        acknowledgeNotificationOnboarding()
        syncPermissionOnboardingStep()
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

    func addMacroStep(_ kind: AutomationMacroStep.Kind, before destinationStepID: AutomationMacroStep.ID? = nil) {
        insertMacroStep(AutomationMacroStep(kind: kind), before: destinationStepID)
        setStatus("\(kind.title) added to the macro flow.", color: .secondaryLabelColor)
    }

    func moveMacroStep(_ stepID: AutomationMacroStep.ID, before destinationStepID: AutomationMacroStep.ID?) {
        guard stepID != destinationStepID else {
            return
        }

        guard let sourceIndex = macroSteps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        let movedStep = macroSteps.remove(at: sourceIndex)
        let destinationIndex = resolvedMacroInsertionIndex(before: destinationStepID)
        macroSteps.insert(movedStep, at: destinationIndex)
        persistMacroSteps()
    }

    func removeMacroStep(_ stepID: AutomationMacroStep.ID) {
        guard let index = macroSteps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        let removedStep = macroSteps.remove(at: index)
        persistMacroSteps()
        setStatus("\(removedStep.kind.title) removed from the macro flow.", color: .secondaryLabelColor)
    }

    func clearMacroSteps() {
        macroSteps = []
        persistMacroSteps()
        setStatus("Macro flow cleared.", color: .secondaryLabelColor)
    }

    func resetMacroSteps() {
        startWithCapture = true
        macroSteps = AutomationMacroStep.defaultFlow
        persistMacroSteps()
        setStatus("Macro flow reset to the default capture sequence.", color: .secondaryLabelColor)
    }

    func updateMacroWaitDuration(for stepID: AutomationMacroStep.ID, seconds: Double) {
        guard let index = macroSteps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        macroSteps[index].waitDuration = min(max(seconds, 0.1), AutomationMacroStep.maxWaitDuration)
        persistMacroSteps()
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

        await stopTargetPreview()

        do {
            let appliedSize = try await captureService.resizeWindow(selectedWindow, to: windowSize)
            if let refreshedWindow = try? await captureService.refreshWindow(selectedWindow) {
                self.selectedWindow = refreshedWindow
                await startTargetPreview(for: refreshedWindow)
            } else {
                await startTargetPreview(for: selectedWindow)
            }
            setStatus(
                "Resized window to \(Int(appliedSize.width)) x \(Int(appliedSize.height)).",
                color: .systemGreen
            )
        } catch {
            await startTargetPreview(for: selectedWindow)
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
        let configuredMacroSteps = macroSteps
        let shouldStartWithCapture = startWithCapture
        automationCaptureCountText = "\(captureCount)"

        guard configuredMacroSteps.contains(where: \.isCapture) else {
            setStatus("Add at least one Capture step in Settings > Macro before starting repeat capture.", color: .systemOrange)
            return
        }

        automationTask = Task { [weak self] in
            await self?.runAutomation(
                captureCount: captureCount,
                cropInsets: cropInsets,
                macroSteps: configuredMacroSteps,
                startWithCapture: shouldStartWithCapture
            )
        }
    }

    func startAutomation() {
        startAutomationFromHotKey()
    }

    func chooseWindow() async {
        refreshPermissions()

        guard hasPermission else {
            setStatus(WindowCaptureError.permissionDenied.localizedDescription, color: .systemOrange)
            return
        }

        isChoosingWindow = true
        setStatus("Click the window you want to capture.", color: .secondaryLabelColor)
        defer { isChoosingWindow = false }

        do {
            let chosenWindow = try await captureService.chooseWindow()
            selectedWindow = chosenWindow
            await startTargetPreview(for: chosenWindow)
            setStatus("Selected \(chosenWindow.appName): \(chosenWindow.title)", color: .systemGreen)
        } catch WindowCaptureError.windowPickerCancelled {
            setStatus("Window selection cancelled.", color: .secondaryLabelColor)
        } catch {
            setStatus(error.localizedDescription, color: .systemRed)
        }
    }

    func presentPermissionOnboarding() {
        isShowingPermissionOnboarding = true
        activePermissionOnboardingStep = permissionOnboardingSteps.first ?? .ready
        syncPermissionOnboardingStep()
    }

    func dismissPermissionOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSeenPermissionOnboarding)
        isShowingPermissionOnboarding = false
    }

    func completePermissionOnboarding() async {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSeenPermissionOnboarding)
        isShowingPermissionOnboarding = false

        if hasPermission {
            await loadWindows()
        }
    }

    func handleAppDidBecomeActive() async {
        let previousHasPermission = hasPermission
        let previousHasAccessibilityPermission = hasAccessibilityPermission

        refreshPermissions()
        await refreshNotificationPermissionState()
        if hasNotificationPermission {
            acknowledgeNotificationOnboarding()
        }
        syncPermissionOnboardingStep()

        if hasPermission && !previousHasPermission {
            await loadWindows()
        } else if previousHasAccessibilityPermission != hasAccessibilityPermission {
            objectWillChange.send()
        }
    }

    func stopAutomation() {
        guard let automationTask else {
            setStatus("No automation is running.", color: .secondaryLabelColor)
            return
        }

        automationTask.cancel()
        setStatus("Stopping automation...", color: .systemOrange)
    }

    private func runAutomation(
        captureCount: Int,
        cropInsets: CaptureInsets,
        macroSteps: [AutomationMacroStep],
        startWithCapture: Bool
    ) async {
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
                macroSteps: macroSteps,
                startWithCapture: startWithCapture,
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

    func openResolvedSaveLocation() {
        let folderURL = resolvedSaveLocationURL

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        } catch {
            setStatus("Could not open save location: \(error.localizedDescription)", color: .systemRed)
        }
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

    func checkForAppUpdates() async {
        appUpdateStatus = .checking

        let result = await appSupportService.checkForUpdates()
        switch result {
        case .upToDate(let latestVersion):
            appUpdateStatus = .upToDate(latestVersion: latestVersion)
            setStatus("You're on the latest published version (\(latestVersion)).", color: .systemGreen)
        case .updateAvailable(let latestVersion):
            appUpdateStatus = .updateAvailable(latestVersion: latestVersion)
            setStatus("A newer version (\(latestVersion)) is available.", color: .systemOrange)
        case .unavailable(let reason):
            appUpdateStatus = .unavailable(reason: reason)
            setStatus(reason, color: .secondaryLabelColor)
        }
    }

    func sendSupportEmail(_ kind: SupportEmailKind) {
        guard appSupportService.openSupportEmail(kind) else {
            setStatus("The mail app could not be opened.", color: .systemRed)
            return
        }

        switch kind {
        case .feedback:
            setStatus("Feedback email opened in your default mail app.", color: .systemGreen)
        case .bugReport:
            setStatus("Bug report email opened in your default mail app.", color: .systemGreen)
        }
    }

    private func refreshPermissions() {
        hasPermission = captureService.hasScreenRecordingPermission()
        hasAccessibilityPermission = captureService.hasAccessibilityPermission()
    }

    private func startTargetPreview(for window: WindowInfo) async {
        targetPreviewImage = nil
        isTargetPreviewActive = false
        let previewID = UUID()
        targetPreviewID = previewID

        do {
            try await captureService.startLivePreview(for: window) { [weak self, previewID] image in
                guard let self, targetPreviewID == previewID else {
                    return
                }

                targetPreviewImage = image
                isTargetPreviewActive = true
            }
        } catch {
            guard targetPreviewID == previewID else {
                return
            }

            isTargetPreviewActive = false
            targetPreviewImage = nil
        }
    }

    private func stopTargetPreview() async {
        targetPreviewID = UUID()
        targetPreviewImage = nil
        isTargetPreviewActive = false
        await captureService.stopLivePreview()
    }

    private func shouldAutoPresentPermissionOnboarding() -> Bool {
        false
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

    private func restoreMacroSteps() {
        guard let storedData = UserDefaults.standard.data(forKey: UserDefaultsKey.automationMacroSteps) else {
            macroSteps = AutomationMacroStep.defaultFlow
            persistMacroSteps()
            return
        }

        do {
            macroSteps = try JSONDecoder().decode([AutomationMacroStep].self, from: storedData)
        } catch {
            macroSteps = AutomationMacroStep.defaultFlow
            persistMacroSteps()
            setStatus("The saved macro could not be read, so the default flow was restored.", color: .systemOrange)
        }
    }

    private func restoreStartWithCapturePreference() {
        if UserDefaults.standard.object(forKey: UserDefaultsKey.automationStartWithCapture) == nil {
            startWithCapture = true
        } else {
            startWithCapture = UserDefaults.standard.bool(forKey: UserDefaultsKey.automationStartWithCapture)
        }
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

    private func insertMacroStep(_ step: AutomationMacroStep, before destinationStepID: AutomationMacroStep.ID?) {
        let destinationIndex = resolvedMacroInsertionIndex(before: destinationStepID)
        macroSteps.insert(step, at: destinationIndex)
        persistMacroSteps()
    }

    private func resolvedMacroInsertionIndex(before destinationStepID: AutomationMacroStep.ID?) -> Int {
        guard
            let destinationStepID,
            let destinationIndex = macroSteps.firstIndex(where: { $0.id == destinationStepID })
        else {
            return macroSteps.endIndex
        }

        return destinationIndex
    }

    private func persistMacroSteps() {
        guard let encodedSteps = try? JSONEncoder().encode(macroSteps) else {
            return
        }

        UserDefaults.standard.set(encodedSteps, forKey: UserDefaultsKey.automationMacroSteps)
    }

    private func persistStartWithCapturePreference() {
        UserDefaults.standard.set(startWithCapture, forKey: UserDefaultsKey.automationStartWithCapture)
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

    private func refreshNotificationPermissionState() async {
        notificationPermissionState = await notificationManager.authorizationState()
    }

    private func acknowledgeNotificationOnboarding() {
        guard !hasAcknowledgedNotificationOnboarding else {
            return
        }

        hasAcknowledgedNotificationOnboarding = true
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasAcknowledgedNotificationOnboarding)
    }

    private func syncPermissionOnboardingStep() {
        let orderedSteps = permissionOnboardingSteps
        guard !orderedSteps.isEmpty else {
            activePermissionOnboardingStep = .ready
            return
        }

        if orderedSteps.contains(activePermissionOnboardingStep) {
            return
        }

        let currentOrder = activePermissionOnboardingStep.rawValue
        if let nextAvailableStep = orderedSteps.first(where: { $0.rawValue >= currentOrder }) {
            activePermissionOnboardingStep = nextAvailableStep
        } else if let lastStep = orderedSteps.last {
            activePermissionOnboardingStep = lastStep
        }
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
        guard await authorizationState() == .authorized else {
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

    func authorizationState() async -> ContentViewModel.NotificationPermissionState {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAuthorizationIfNeeded() async -> ContentViewModel.NotificationPermissionState {
        switch await authorizationState() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            do {
                let granted = try await requestAuthorization()
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }
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
