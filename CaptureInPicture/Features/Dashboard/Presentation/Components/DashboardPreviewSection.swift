import AppKit
import SwiftUI

struct DashboardPreviewSection: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            livePreviewHeader

            livePreviewSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private var livePreviewHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Live Preview")
                    .font(.title2.weight(.semibold))

                Text(targetSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    await viewModel.chooseWindow()
                }
            } label: {
                Label(viewModel.selectedWindow == nil ? "Choose Target" : "Change Target", systemImage: "macwindow.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isChoosingWindow ||
                viewModel.isCapturing ||
                viewModel.isAutomating ||
                !viewModel.hasPermission
            )
        }
    }

    @ViewBuilder
    private var livePreviewSurface: some View {
        if let targetPreviewImage = viewModel.targetPreviewImage {
            ZStack {
                Color.black.opacity(0.9)

                Image(nsImage: targetPreviewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            }
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.hasPermission ? "macwindow" : "lock.shield")
                            .font(.system(size: 42, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text(viewModel.hasPermission ? "No target selected" : "Screen Recording is required")
                            .font(.headline)

                        Text(viewModel.hasPermission ? "Choose a target window to start the live preview." : "Use the Ready controls above to allow window capture.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                }
        }
    }

    private var targetSummary: String {
        guard let selectedWindow = viewModel.selectedWindow else {
            return viewModel.hasPermission ? "Choose one app window for screenshots, resizing, and repeat capture." : "Ready needs Screen Recording before a target can be selected."
        }

        return "\(selectedWindow.appName) - \(selectedWindow.title) · \(selectedWindow.sizeDescription)"
    }
}
