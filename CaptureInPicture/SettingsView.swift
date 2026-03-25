//
//  SettingsView.swift
//  CaptureInPicture
//
//  Created by Codex on 3/23/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: ContentViewModel

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            captureTab
                .tabItem {
                    Label("Capture", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 760, height: 540)
    }

    private var generalTab: some View {
        Form {
            Section {
                permissionRow(
                    title: "Screen Recording",
                    isEnabled: viewModel.hasPermission,
                    readyText: "Ready to list and capture windows.",
                    missingText: "Required to see other app windows."
                )

                permissionRow(
                    title: "Accessibility",
                    isEnabled: viewModel.hasAccessibilityPermission,
                    readyText: "Ready for repeat capture and window resizing.",
                    missingText: "Required for repeat capture and window resizing."
                )

                permissionRow(
                    title: "Notifications",
                    isEnabled: viewModel.hasNotificationPermission,
                    readyText: "Ready to show capture completion alerts without interrupting the capture flow.",
                    missingText: "Optional, but useful if you want completion alerts without a prompt appearing during capture."
                )

                HStack(spacing: 10) {
                    Button("Open Guided Setup") {
                        viewModel.presentPermissionOnboarding()
                    }

                    Button("Open Screen Settings") {
                        viewModel.openSystemSettings()
                    }

                    Button("Open Accessibility Settings") {
                        viewModel.openAccessibilitySettings()
                    }

                    Button("Open Notification Settings") {
                        viewModel.openNotificationSettings()
                    }
                }
            } header: {
                HStack {
                    Text("Permissions")

                    Spacer(minLength: 0)

                    Button {
                        Task {
                            await viewModel.handleAppDidBecomeActive()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh permission status")
                    .disabled(viewModel.isLoading)
                }
            }

            Section("Save Location") {
                Text("Single captures save directly into the selected folder. Repeat capture creates a timestamped subfolder inside it.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Choose Folder") {
                        viewModel.chooseSaveFolder()
                    }

                    Button("Open Folder") {
                        viewModel.openSelectedSaveFolder()
                    }
                    .disabled(viewModel.selectedSaveFolderURL == nil)

                    Button("Use Default") {
                        viewModel.clearSaveFolder()
                    }
                }

                Text(viewModel.selectedSaveFolderURL?.path ?? "Default location: Pictures/CaptureInPicture")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .formStyle(.grouped)
    }

    private var captureTab: some View {
        Form {
            Section("Capture Insets") {
                Text("Trim the captured image inward before saving. The same inset values apply to one-shot and repeat capture.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    insetField(title: "Top", text: $viewModel.captureInsetTopText)
                    insetField(title: "Bottom", text: $viewModel.captureInsetBottomText)
                    insetField(title: "Left", text: $viewModel.captureInsetLeftText)
                    insetField(title: "Right", text: $viewModel.captureInsetRightText)
                }

                Button("Reset Insets") {
                    viewModel.resetCaptureInsets()
                }
            }

            Section("Automation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat capture focuses the selected app, captures the window, sends Right Arrow, and repeats.")
                        .foregroundStyle(.secondary)

                    Label(viewModel.automationStartShortcutDescription, systemImage: "play.circle")
                    Label(viewModel.automationStopShortcutDescription, systemImage: "stop.circle")
                }

                HStack(spacing: 10) {
                    Button("Reveal Capture") {
                        viewModel.revealLastSavedCapture()
                    }
                    .disabled(viewModel.lastSavedURL == nil)
                }

                if let folderURL = viewModel.lastAutomationFolderURL {
                    Text(folderURL.path)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(
        title: String,
        isEnabled: Bool,
        readyText: String,
        missingText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isEnabled ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(isEnabled ? readyText : missingText)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func insetField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    viewModel.normalizeCaptureInsets()
                }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ContentViewModel())
}
