import SwiftUI

struct SettingsGeneralTab: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Form {
            Section {
                SettingsPermissionRow(
                    title: "Screen Recording",
                    isEnabled: viewModel.hasPermission,
                    readyText: "Ready to list and capture windows.",
                    missingText: "Required to see other app windows."
                )

                SettingsPermissionRow(
                    title: "Accessibility",
                    isEnabled: viewModel.hasAccessibilityPermission,
                    readyText: "Ready for repeat capture, macro input, and window resizing.",
                    missingText: "Required for repeat capture macros and window resizing."
                )

                SettingsPermissionRow(
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
}

private struct SettingsPermissionRow: View {
    let title: String
    let isEnabled: Bool
    let readyText: String
    let missingText: String

    var body: some View {
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
}
