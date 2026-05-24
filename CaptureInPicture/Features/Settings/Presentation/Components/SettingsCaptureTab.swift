import SwiftUI

struct SettingsCaptureTab: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Form {
            Section("Capture Insets") {
                Text("Trim the captured image inward before saving. The same inset values apply to one-shot and repeat capture.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    SettingsInsetField(title: "Top", text: $viewModel.captureInsetTopText) {
                        viewModel.normalizeCaptureInsets()
                    }

                    SettingsInsetField(title: "Bottom", text: $viewModel.captureInsetBottomText) {
                        viewModel.normalizeCaptureInsets()
                    }

                    SettingsInsetField(title: "Left", text: $viewModel.captureInsetLeftText) {
                        viewModel.normalizeCaptureInsets()
                    }

                    SettingsInsetField(title: "Right", text: $viewModel.captureInsetRightText) {
                        viewModel.normalizeCaptureInsets()
                    }
                }

                Button("Reset Insets") {
                    viewModel.resetCaptureInsets()
                }
            }

            Section("Automation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat capture follows the Macro tab flow and stops after it has saved the requested number of Capture steps.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Repeat Count")

                        Spacer()

                        TextField("0", text: $viewModel.automationCaptureCountText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .multilineTextAlignment(.trailing)
                            .onSubmit {
                                viewModel.normalizeAutomationCaptureCount()
                            }
                    }

                    Label(viewModel.automationFlowSummary, systemImage: "square.stack.3d.up")
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
}

private struct SettingsInsetField: View {
    let title: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("0", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .multilineTextAlignment(.trailing)
                .onSubmit(onSubmit)
        }
    }
}
