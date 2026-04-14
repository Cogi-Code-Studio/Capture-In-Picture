import SwiftUI

struct DashboardPermissionBanner: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before You Start")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                DashboardPermissionBadge(
                    title: "Screen Recording",
                    isEnabled: viewModel.hasPermission,
                    readyText: "Ready to list and capture app windows.",
                    missingText: "Needed before any window appears in the main list."
                )

                DashboardPermissionBadge(
                    title: "Accessibility",
                    isEnabled: viewModel.hasAccessibilityPermission,
                    readyText: "Ready for repeat capture and window resizing.",
                    missingText: "Needed for repeat capture and resizing another app."
                )
            }

            HStack(spacing: 10) {
                Button("Guided Setup") {
                    viewModel.presentPermissionOnboarding()
                }

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
}

private struct DashboardPermissionBadge: View {
    let title: String
    let isEnabled: Bool
    let readyText: String
    let missingText: String

    var body: some View {
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
}
