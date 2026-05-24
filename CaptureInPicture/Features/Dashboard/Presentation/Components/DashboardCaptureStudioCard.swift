import SwiftUI

struct DashboardCaptureStudioCard: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Capture Controls")
                .font(.title3.weight(.semibold))

            primaryActions

            VStack(alignment: .leading, spacing: 12) {
                Label("Window Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.headline)

                HStack(spacing: 10) {
                    DashboardMetricField(title: "Width", text: $viewModel.windowWidthText) {
                        viewModel.normalizeWindowSize()
                    }

                    DashboardMetricField(title: "Height", text: $viewModel.windowHeightText) {
                        viewModel.normalizeWindowSize()
                    }
                }

                HStack(spacing: 8) {
                    Button("Load") {
                        viewModel.useSelectedWindowSize()
                    }
                    .disabled(viewModel.selectedWindow == nil)

                    Button {
                        Task {
                            await viewModel.resizeSelectedWindow()
                        }
                    } label: {
                        Label(viewModel.isResizingWindow ? "Applying..." : "Apply", systemImage: "checkmark")
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
        }
        .controlSize(.small)
        .dashboardCard()
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
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
