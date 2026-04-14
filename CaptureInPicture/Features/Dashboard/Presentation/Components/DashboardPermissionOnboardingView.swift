import AppKit
import SwiftUI

struct DashboardPermissionOnboardingView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        let step = viewModel.activePermissionOnboardingStep
        let pageCount = max(viewModel.permissionOnboardingSteps.count, 1)

        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Guided Setup")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("One permission at a time.")
                        .font(.system(size: 34, weight: .bold))

                    Text("Finish the current page and the next card will slide into place. The goal is a cleaner first-run setup, not a wall of system prompts.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if viewModel.canDismissPermissionOnboarding {
                    Button("Set Up Later") {
                        viewModel.dismissPermissionOnboarding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

            HStack(spacing: 10) {
                Text("\(viewModel.permissionOnboardingPageNumber) / \(pageCount)")
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()

                Text(compactTitle(for: step))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                ForEach(Array(viewModel.permissionOnboardingSteps.enumerated()), id: \.element.id) { index, onboardingStep in
                    Capsule()
                        .fill(index == viewModel.permissionOnboardingStepIndex ? accentColor(for: onboardingStep) : Color.white.opacity(0.28))
                        .frame(width: index == viewModel.permissionOnboardingStepIndex ? 30 : 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(accentColor(for: step).opacity(0.16))
                            .frame(width: 82, height: 82)

                        Image(systemName: symbol(for: step))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(accentColor(for: step))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(eyebrow(for: step))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(title(for: step))
                            .font(.system(size: 30, weight: .bold))

                        Text(description(for: step))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 14) {
                    ForEach(highlights(for: step), id: \.self) { item in
                        DashboardOnboardingHighlightRow(text: item)
                    }
                }

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(nsColor: viewModel.statusColor))
                        .frame(width: 10, height: 10)

                    Text(viewModel.statusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    if let tertiaryAction = tertiaryAction(for: step) {
                        Button(tertiaryAction.title, action: tertiaryAction.handler)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }

                    Spacer(minLength: 0)

                    if let secondaryAction = secondaryAction(for: step) {
                        Button(secondaryAction.title, action: secondaryAction.handler)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }

                    Button(primaryActionTitle(for: step)) {
                        handlePrimaryAction(for: step)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: 860, maxHeight: .infinity, alignment: .leading)
            .dashboardCard(highlighted: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(32)
    }

    private func compactTitle(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording:
            return "Screen Recording"
        case .accessibility:
            return "Accessibility"
        case .notifications:
            return "Notifications"
        case .ready:
            return "Ready"
        }
    }

    private func eyebrow(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording, .accessibility:
            return "Step \(viewModel.permissionOnboardingPageNumber)"
        case .notifications:
            return "Optional"
        case .ready:
            return "All Set"
        }
    }

    private func title(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording:
            return viewModel.hasPermission ? "Screen Recording is ready" : "Allow Screen Recording"
        case .accessibility:
            return viewModel.hasAccessibilityPermission ? "Accessibility is ready" : "Allow Accessibility"
        case .notifications:
            return viewModel.hasNotificationPermission ? "Notifications are ready" : "Allow Notifications"
        case .ready:
            return "You're ready to capture"
        }
    }

    private func description(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording:
            return "Needed to list running windows and save screenshots from the one you choose."
        case .accessibility:
            return "Needed for repeat capture macros and window resizing so the app can focus another window and send key input."
        case .notifications:
            return "Optional, but useful if you want completion banners without being surprised by a prompt during your first capture."
        case .ready:
            return "The required permissions are in place. From here you'll land on the capture studio with the usual controls."
        }
    }

    private func highlights(for step: ContentViewModel.PermissionOnboardingStep) -> [String] {
        switch step {
        case .screenRecording:
            return [
                viewModel.hasPermission
                    ? "macOS already recognizes this app for Screen Recording, so the window list can load immediately."
                    : "Tap the request button to trigger the macOS prompt instead of surprising the user with it on the main screen.",
                "If you already denied it once, use System Settings to enable the toggle and return here.",
                "When permission is active, the next step becomes available automatically."
            ]
        case .accessibility:
            return [
                viewModel.hasAccessibilityPermission
                    ? "Accessibility is already enabled, so repeat capture and window resizing can work right away."
                    : "This gives the app permission to focus another app window and advance it during repeat capture.",
                "Repeat capture can send arrow keys, waits, and captures from your macro flow, so this permission is what makes the automation reliable.",
                "If the macOS prompt does not reappear, open Accessibility settings and turn the app on manually."
            ]
        case .notifications:
            return [
                viewModel.hasNotificationPermission
                    ? "Notification permission is already enabled, so completion banners can appear without interrupting future capture sessions."
                    : "Request it here once so the first capture does not get interrupted by a late permission prompt.",
                "This is optional. Even if you skip it, capture and repeat capture still work normally.",
                "If notifications were denied before, open Notification settings and enable them manually for this app."
            ]
        case .ready:
            return [
                "The dashboard will now open with the selected permissions reflected in the status banner and controls.",
                "If Screen Recording was just enabled, refreshing the window list should show capturable windows right away.",
                "You can reopen guided setup later whenever you want from the permission banner."
            ]
        }
    }

    private func symbol(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording:
            return "rectangle.on.rectangle"
        case .accessibility:
            return "figure.wave.circle"
        case .notifications:
            return "bell.badge"
        case .ready:
            return "checkmark.seal.fill"
        }
    }

    private func accentColor(for step: ContentViewModel.PermissionOnboardingStep) -> Color {
        switch step {
        case .screenRecording:
            return .blue
        case .accessibility:
            return .orange
        case .notifications:
            return .pink
        case .ready:
            return .green
        }
    }

    private func primaryActionTitle(for step: ContentViewModel.PermissionOnboardingStep) -> String {
        switch step {
        case .screenRecording:
            return viewModel.hasPermission ? "Checking..." : "Request Screen Recording"
        case .accessibility:
            return viewModel.hasAccessibilityPermission ? "Checking..." : "Request Accessibility"
        case .notifications:
            return viewModel.hasNotificationPermission ? "Checking..." : "Request Notifications"
        case .ready:
            return "Open Capture Studio"
        }
    }

    private func tertiaryAction(for step: ContentViewModel.PermissionOnboardingStep) -> (title: String, handler: () -> Void)? {
        switch step {
        case .notifications where !viewModel.hasNotificationPermission:
            return ("Continue Without Alerts", viewModel.skipNotificationOnboardingStep)
        default:
            return nil
        }
    }

    private func secondaryAction(for step: ContentViewModel.PermissionOnboardingStep) -> (title: String, handler: () -> Void)? {
        switch step {
        case .screenRecording where !viewModel.hasPermission:
            return ("Open Screen Settings", viewModel.openSystemSettings)
        case .accessibility where !viewModel.hasAccessibilityPermission:
            return ("Open Accessibility Settings", viewModel.openAccessibilitySettings)
        case .notifications where !viewModel.hasNotificationPermission:
            return ("Open Notification Settings", viewModel.openNotificationSettings)
        default:
            return nil
        }
    }

    private func handlePrimaryAction(for step: ContentViewModel.PermissionOnboardingStep) {
        switch step {
        case .screenRecording:
            guard !viewModel.hasPermission else { return }
            viewModel.requestPermission()
        case .accessibility:
            guard !viewModel.hasAccessibilityPermission else { return }
            viewModel.requestAccessibilityPermission()
        case .notifications:
            guard !viewModel.hasNotificationPermission else { return }
            Task {
                await viewModel.requestNotificationPermission()
            }
        case .ready:
            Task {
                await viewModel.completePermissionOnboarding()
            }
        }
    }
}

private struct DashboardOnboardingHighlightRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, alignment: .top)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
