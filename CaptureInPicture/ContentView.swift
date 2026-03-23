//
//  ContentView.swift
//  CaptureInPicture
//
//  Created by RyuWoong on 3/20/26.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ContentViewModel
    private let windowSelectionCardHeight: CGFloat = 520

    var body: some View {
        ZStack {
            backgroundLayer

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection

                        if !viewModel.hasPermission || !viewModel.hasAccessibilityPermission {
                            permissionBanner
                        }

                        HStack(alignment: .top, spacing: 20) {
                            windowSelectionCard
                                .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity)

                            previewSection
                                .frame(width: 360)

                            captureStudioCard
                                .frame(width: 360)
                        }
                    }
                    .padding(28)
                }
                .navigationTitle("Capture In Picture")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        SettingsLink {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 760)
        .task {
            await viewModel.loadWindows()
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor),
                Color.accentColor.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 380, height: 380)
                .blur(radius: 20)
                .offset(x: -60, y: -90)
        }
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture In Picture")
                        .font(.system(size: 34, weight: .bold))

                    Text("Keep the main flow focused: choose a window, set the size, decide how many frames to take, and capture right away.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                statusPill
            }

            HStack(spacing: 12) {
                heroMetric(
                    title: "Selected Window",
                    value: selectedWindowTitle,
                    systemImage: "macwindow"
                )

                heroMetric(
                    title: "Window Size",
                    value: selectedWindowSize,
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )

                heroMetric(
                    title: "Repeat Count",
                    value: viewModel.automationCaptureCountText,
                    systemImage: "repeat"
                )
            }

            HStack(spacing: 12) {
                heroMetric(
                    title: "Capture Insets",
                    value: captureInsetsSummary,
                    systemImage: "crop"
                )

                Button {
                    viewModel.copySaveLocationToClipboard()
                } label: {
                    heroMetric(
                        title: "Save Location",
                        value: saveLocationSummary,
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.plain)
                .help("Copy save location path")
            }
        }
        .dashboardCard(highlighted: true)
    }

    private var statusPill: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: viewModel.statusColor))
                .frame(width: 10, height: 10)

            Text(viewModel.statusMessage)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.55), in: Capsule())
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before You Start")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                permissionBadge(
                    title: "Screen Recording",
                    isEnabled: viewModel.hasPermission,
                    readyText: "Ready to list and capture app windows.",
                    missingText: "Needed before any window appears in the main list."
                )

                permissionBadge(
                    title: "Accessibility",
                    isEnabled: viewModel.hasAccessibilityPermission,
                    readyText: "Ready for repeat capture and window resizing.",
                    missingText: "Needed for repeat capture and resizing another app."
                )
            }

            HStack(spacing: 10) {
                if !viewModel.hasPermission {
                    Button("Request Screen Permission") {
                        viewModel.requestPermission()
                    }

                    Button("Open Screen Settings") {
                        viewModel.openSystemSettings()
                    }
                }

                if !viewModel.hasAccessibilityPermission {
                    Button("Request Accessibility") {
                        viewModel.requestAccessibilityPermission()
                    }

                    Button("Open Accessibility Settings") {
                        viewModel.openAccessibilitySettings()
                    }
                }

                Button("Refresh Windows") {
                    Task {
                        await viewModel.loadWindows()
                    }
                }
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .dashboardCard()
    }

    private var windowSelectionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a Window")
                        .font(.title2.weight(.semibold))

                    Text("Pick the running window you want to capture. The current selection drives both one-shot and repeat capture.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Refresh") {
                    Task {
                        await viewModel.loadWindows()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(viewModel.isLoading)
            }

            Group {
                if viewModel.windows.isEmpty {
                    emptyWindowState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.windows) { window in
                                windowRow(for: window)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: 12) {
                Label(selectedWindowTitle, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(viewModel.selectedWindow == nil ? .secondary : .primary)

                if let selectedWindow = viewModel.selectedWindow {
                    Text(selectedWindow.appName)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .frame(height: windowSelectionCardHeight)
        .dashboardCard()
    }

    private var emptyWindowState: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: viewModel.hasPermission ? "macwindow" : "lock.shield")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(viewModel.hasPermission ? "No capturable windows are available right now." : "Grant permission to see available windows.")
                        .font(.headline)

                    Text(viewModel.hasPermission ? "Open an app window and refresh the list." : "Use the permission banner above or open Settings from the menu bar.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(24)
            }
    }

    private func windowRow(for window: WindowInfo) -> some View {
        let isSelected = window.id == viewModel.selectedWindowID

        return Button {
            viewModel.selectedWindowID = window.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "macwindow.badge.plus" : "macwindow")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : (window.isActive ? .blue : .secondary))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(window.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(window.appName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(window.sizeDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.42))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var captureStudioCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Capture Studio")
                    .font(.title2.weight(.semibold))

                Text("Tune the window size, choose the repeat count, then run a single test capture or a repeated capture session.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Window Size")
                    .font(.headline)

                HStack(spacing: 12) {
                    metricField(title: "Width", text: $viewModel.windowWidthText) {
                        viewModel.normalizeWindowSize()
                    }
                    metricField(title: "Height", text: $viewModel.windowHeightText) {
                        viewModel.normalizeWindowSize()
                    }
                }

                HStack(spacing: 10) {
                    Button("Load Current Size") {
                        viewModel.useSelectedWindowSize()
                    }
                    .disabled(viewModel.selectedWindow == nil)

                    Button {
                        Task {
                            await viewModel.resizeSelectedWindow()
                        }
                    } label: {
                        Label(viewModel.isResizingWindow ? "Applying..." : "Apply Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.selectedWindow == nil ||
                        viewModel.isResizingWindow ||
                        viewModel.isCapturing ||
                        viewModel.isAutomating
                    )
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Repeat Capture")
                    .font(.headline)

                HStack(spacing: 12) {
                    metricField(title: "Count", text: $viewModel.automationCaptureCountText) {
                        viewModel.normalizeAutomationCaptureCount()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Flow")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Capture, send Right Arrow, capture again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !viewModel.hasAccessibilityPermission {
                    Label("Accessibility permission is still required for repeat capture and resizing.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Shortcuts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(viewModel.automationStartShortcutDescription, systemImage: "play.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(viewModel.automationStopShortcutDescription, systemImage: "stop.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.captureSelectedWindow()
                    }
                } label: {
                    actionButtonLabel(
                        title: viewModel.isCapturing ? "Capturing..." : "Try One Capture",
                        subtitle: "Save the current window as a PNG right now.",
                        systemImage: "camera.aperture"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    viewModel.selectedWindow == nil ||
                    viewModel.isCapturing ||
                    viewModel.isAutomating ||
                    !viewModel.hasPermission
                )

                if viewModel.isAutomating {
                    Button {
                        viewModel.stopAutomation()
                    } label: {
                        actionButtonLabel(
                            title: "Stop Repeat Capture",
                            subtitle: "End the current automated session.",
                            systemImage: "stop.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        viewModel.startAutomation()
                    } label: {
                        actionButtonLabel(
                            title: "Start Repeat Capture",
                            subtitle: "Run the selected window through the repeat workflow.",
                            systemImage: "repeat.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(
                        viewModel.selectedWindow == nil ||
                        viewModel.isCapturing ||
                        viewModel.isAutomating ||
                        !viewModel.hasPermission
                    )
                }
            }
        }
        .dashboardCard()
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(.title2.weight(.semibold))

                    Text("Use one-shot capture to test framing, then move into repeat capture when the setup looks right.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    if viewModel.lastSavedURL != nil {
                        Button("Reveal Capture") {
                            viewModel.revealLastSavedCapture()
                        }
                    }
                }
            }

            if let previewImage = viewModel.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Your latest captured window will appear here.")
                                .font(.headline)

                            Text("Run a one-shot capture to quickly check framing and crop.")
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            if let lastSavedURL = viewModel.lastSavedURL {
                Text(lastSavedURL.path)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .dashboardCard()
    }

    private func heroMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func permissionBadge(
        title: String,
        isEnabled: Bool,
        readyText: String,
        missingText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isEnabled ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(isEnabled ? readyText : missingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metricField(title: String, text: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .onSubmit {
                    onSubmit()
                }
        }
    }

    private func actionButtonLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var selectedWindowTitle: String {
        viewModel.selectedWindow?.title ?? "No window selected"
    }

    private var selectedWindowSize: String {
        if let selectedWindow = viewModel.selectedWindow {
            return selectedWindow.sizeDescription
        }

        if !viewModel.windowWidthText.isEmpty, !viewModel.windowHeightText.isEmpty {
            return "\(viewModel.windowWidthText) x \(viewModel.windowHeightText)"
        }

        return "Use the controls below"
    }

    private var captureInsetsSummary: String {
        "T \(viewModel.captureInsetTopText)  B \(viewModel.captureInsetBottomText)  L \(viewModel.captureInsetLeftText)  R \(viewModel.captureInsetRightText)"
    }

    private var saveLocationSummary: String {
        viewModel.selectedSaveFolderURL?.path ?? "Pictures/CaptureInPicture"
    }
}

private struct DashboardCardModifier: ViewModifier {
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(highlighted ? 28 : 22)
            .background {
                RoundedRectangle(cornerRadius: highlighted ? 30 : 28, style: .continuous)
                    .fill(highlighted ? .thinMaterial : .regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: highlighted ? 30 : 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(highlighted ? 0.34 : 0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(highlighted ? 0.10 : 0.07), radius: highlighted ? 24 : 18, y: 10)
    }
}

private extension View {
    func dashboardCard(highlighted: Bool = false) -> some View {
        modifier(DashboardCardModifier(highlighted: highlighted))
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentViewModel())
}
