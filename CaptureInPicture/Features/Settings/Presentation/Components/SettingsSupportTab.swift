import SwiftUI

struct SettingsSupportTab: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Form {
            Section("Version") {
                HStack {
                    Text("Installed Version")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 16)

                    Text(viewModel.installedAppVersion)
                        .textSelection(.enabled)
                }

                HStack {
                    Text("Build")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 16)

                    Text(viewModel.installedAppBuild)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(updateSummaryTitle)
                        .font(.headline)

                    Text(updateSummaryMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if case .checking = viewModel.appUpdateStatus {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 10) {
                    Button("Check Latest Version") {
                        Task {
                            await viewModel.checkForAppUpdates()
                        }
                    }
                    .disabled(isCheckingForUpdates)
                }
            }

            Section("Contact") {
                Text("Send feedback or bug reports straight to the team. The message opens in your default mail app and includes the installed app version automatically.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button(SupportEmailKind.feedback.buttonTitle) {
                        viewModel.sendSupportEmail(.feedback)
                    }

                    Button(SupportEmailKind.bugReport.buttonTitle) {
                        viewModel.sendSupportEmail(.bugReport)
                    }
                }

                HStack {
                    Text("Email")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 16)

                    Text(viewModel.supportEmailAddress)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var isCheckingForUpdates: Bool {
        if case .checking = viewModel.appUpdateStatus {
            return true
        }

        return false
    }

    private var updateSummaryTitle: String {
        switch viewModel.appUpdateStatus {
        case .idle:
            return "Check whether this build is up to date."
        case .checking:
            return "Checking the latest published version..."
        case .upToDate:
            return "This app is up to date."
        case .updateAvailable:
            return "A newer version is available."
        case .unavailable:
            return "Published version info is unavailable."
        }
    }

    private var updateSummaryMessage: String {
        switch viewModel.appUpdateStatus {
        case .idle:
            return "Use Check Latest Version to compare the installed build with the newest published release or tag."
        case .checking:
            return "Contacting the published version feed now."
        case .upToDate(let latestVersion):
            return "You're already on the latest published version: \(latestVersion)."
        case .updateAvailable(let latestVersion):
            return "A newer version is published: \(latestVersion)."
        case .unavailable(let reason):
            return reason
        }
    }
}
