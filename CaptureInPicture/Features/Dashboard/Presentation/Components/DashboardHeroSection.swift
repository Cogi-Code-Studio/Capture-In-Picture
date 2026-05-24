import AppKit
import SwiftUI

struct DashboardHeroSection: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                headerSettingsSummary

                Spacer(minLength: 0)

                DashboardStatusPill(
                    statusMessage: viewModel.statusMessage,
                    statusColor: viewModel.statusColor
                )
            }

            HStack(alignment: .top, spacing: 10) {
                DashboardReadyChip(
                    title: "Screen",
                    message: viewModel.hasPermission ? "Window capture ready" : "Needs Screen Recording",
                    systemImage: "rectangle.on.rectangle",
                    isReady: viewModel.hasPermission
                )

                DashboardReadyChip(
                    title: "Control",
                    message: viewModel.hasAccessibilityPermission ? "Resize and macros ready" : "Needs Accessibility",
                    systemImage: "keyboard",
                    isReady: viewModel.hasAccessibilityPermission
                )

                DashboardReadyChip(
                    title: "Notify",
                    message: viewModel.hasNotificationPermission ? "Completion alerts ready" : "Optional",
                    systemImage: "bell",
                    isReady: viewModel.hasNotificationPermission,
                    isOptional: true
                )

                Spacer(minLength: 0)

                if !viewModel.hasPermission {
                    Button("Request Screen") {
                        viewModel.requestPermission()
                    }
                }

                if !viewModel.hasAccessibilityPermission {
                    Button("Request Accessibility") {
                        viewModel.requestAccessibilityPermission()
                    }
                }

                if !viewModel.hasNotificationPermission {
                    Button("Request Notifications") {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    }
                }

                Button {
                    viewModel.presentPermissionOnboarding()
                } label: {
                    Label("Guided Setup", systemImage: "checklist")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.bar)
    }

    private var headerSettingsSummary: some View {
        HStack(spacing: 10) {
            DashboardHeaderInfoChip(
                title: "Inset",
                value: viewModel.captureInsetSummary,
                systemImage: "crop"
            )

            DashboardHeaderInfoChip(
                title: "Repeat",
                value: viewModel.repeatCaptureSummary,
                systemImage: "repeat"
            )

            Button {
                viewModel.openResolvedSaveLocation()
            } label: {
                DashboardHeaderInfoChip(
                    title: "Location",
                    value: viewModel.saveLocationDisplayPath,
                    systemImage: "folder"
                )
            }
            .buttonStyle(.plain)
            .help("Open save location in Finder")
            .frame(maxWidth: 420, alignment: .leading)
        }
    }
}

private struct DashboardStatusPill: View {
    let statusMessage: String
    let statusColor: NSColor

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: statusColor))
                .frame(width: 8, height: 8)

            Text(statusMessage)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
    }
}

private struct DashboardReadyChip: View {
    let title: String
    let message: String
    let systemImage: String
    let isReady: Bool
    var isOptional = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(isReady ? .green : (isOptional ? .secondary : .orange))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DashboardHeaderInfoChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
