import SwiftUI

struct DashboardCaptureStudioCard: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
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
                    DashboardMetricField(title: "Width", text: $viewModel.windowWidthText) {
                        viewModel.normalizeWindowSize()
                    }

                    DashboardMetricField(title: "Height", text: $viewModel.windowHeightText) {
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
                    DashboardMetricField(title: "Count", text: $viewModel.automationCaptureCountText) {
                        viewModel.normalizeAutomationCaptureCount()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Flow")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(viewModel.automationFlowSummary)
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
                    DashboardActionButtonLabel(
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
                        DashboardActionButtonLabel(
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
                        DashboardActionButtonLabel(
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
}

private struct DashboardMetricField: View {
    let title: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("0", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .rounded).monospacedDigit())
                .onSubmit(onSubmit)
        }
    }
}

private struct DashboardActionButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
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
}
