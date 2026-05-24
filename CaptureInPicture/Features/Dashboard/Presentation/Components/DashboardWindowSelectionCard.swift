import SwiftUI

struct DashboardWindowSelectionCard: View {
    @ObservedObject var viewModel: ContentViewModel
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture Target")
                        .font(.title2.weight(.semibold))

                    Text("Use the system window picker to choose the one window used by screenshots and macro capture.")
                        .foregroundStyle(.secondary)
                }
            }

            selectedWindowState
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Button {
                Task {
                    await viewModel.chooseWindow()
                }
            } label: {
                Label(viewModel.isChoosingWindow ? "창 선택 중..." : "창 선택하기", systemImage: "macwindow.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                viewModel.isChoosingWindow ||
                viewModel.isCapturing ||
                viewModel.isAutomating ||
                !viewModel.hasPermission
            )
        }
        .frame(height: height)
        .dashboardCard()
    }

    @ViewBuilder
    private var selectedWindowState: some View {
        if let selectedWindow = viewModel.selectedWindow {
            VStack(alignment: .leading, spacing: 14) {
                targetPreviewSurface
                    .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 230)

                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedWindow.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(selectedWindow.appName, systemImage: "app.dashed")
                            .lineLimit(1)

                        Text(selectedWindow.sizeDescription)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text("This target drives one-shot screenshots, repeat capture, resizing, and macro key input.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            emptyWindowState
        }
    }

    @ViewBuilder
    private var targetPreviewSurface: some View {
        if let targetPreviewImage = viewModel.targetPreviewImage {
            Image(nsImage: targetPreviewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(12)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                }
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Starting live preview...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
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

                    Text(viewModel.hasPermission ? "No window selected." : "Grant permission to choose a window.")
                        .font(.headline)

                    Text(viewModel.hasPermission ? "Press 창 선택하기 and select a window from the macOS overlay." : "Use the permission banner above or open Settings from the menu bar.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(24)
            }
    }
}
