import SwiftUI

struct DashboardWindowSelectionCard: View {
    @ObservedObject var viewModel: ContentViewModel
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a Window")
                        .font(.title2.weight(.semibold))

                    Text("Pick the running window you want to capture. The current selection drives both one-shot and repeat capture.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer(minLength: 0)

                    Button("Refresh") {
                        Task {
                            await viewModel.loadWindows()
                        }
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(viewModel.isLoading)
                }
            }

            Group {
                if viewModel.windows.isEmpty {
                    emptyWindowState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.windows) { window in
                                DashboardWindowRow(
                                    window: window,
                                    isSelected: window.id == viewModel.selectedWindowID
                                ) {
                                    viewModel.selectedWindowID = window.id
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: height)
        .dashboardCard()
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

                    Text(viewModel.hasPermission ? "No capturable windows are available right now." : "Grant permission to see available windows.")
                        .font(.headline)

                    Text(viewModel.hasPermission ? "Open an app window and refresh the list." : "Use the permission banner above or open Settings from the menu bar.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(24)
            }
    }
}

private struct DashboardWindowRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "macwindow.badge.plus" : "macwindow")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : (window.isActive ? .blue : .secondary))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(window.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(window.appName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(window.sizeDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.42))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
