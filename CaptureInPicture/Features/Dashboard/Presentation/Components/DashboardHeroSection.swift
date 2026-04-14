import AppKit
import SwiftUI

struct DashboardHeroSection: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
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

                DashboardStatusPill(
                    statusMessage: viewModel.statusMessage,
                    statusColor: viewModel.statusColor
                )
            }

            HStack(spacing: 12) {
                DashboardHeroMetric(
                    title: "Selected Window",
                    value: selectedWindowTitle,
                    systemImage: "macwindow"
                )

                DashboardHeroMetric(
                    title: "Window Size",
                    value: selectedWindowSize,
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )

                DashboardHeroMetric(
                    title: "Repeat Count",
                    value: viewModel.automationCaptureCountText,
                    systemImage: "repeat"
                )
            }

            HStack(spacing: 12) {
                DashboardHeroMetric(
                    title: "Capture Insets",
                    value: captureInsetsSummary,
                    systemImage: "crop"
                )

                Button {
                    viewModel.copySaveLocationToClipboard()
                } label: {
                    DashboardHeroMetric(
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
        "Top \(viewModel.captureInsetTopText)  Bottom \(viewModel.captureInsetBottomText)  Left \(viewModel.captureInsetLeftText)  Right \(viewModel.captureInsetRightText)"
    }

    private var saveLocationSummary: String {
        viewModel.selectedSaveFolderURL?.path ?? "Pictures/CaptureInPicture"
    }
}

private struct DashboardStatusPill: View {
    let statusMessage: String
    let statusColor: NSColor

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: statusColor))
                .frame(width: 10, height: 10)

            Text(statusMessage)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.55), in: Capsule())
    }
}

private struct DashboardHeroMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
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
}
