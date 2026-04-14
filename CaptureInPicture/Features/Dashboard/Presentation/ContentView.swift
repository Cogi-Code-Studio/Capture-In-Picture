//
//  ContentView.swift
//  CaptureInPicture
//
//  Created by RyuWoong on 3/20/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var viewModel: ContentViewModel
    private let windowSelectionCardHeight: CGFloat = 520

    var body: some View {
        ZStack {
            DashboardBackgroundView()

            if viewModel.shouldShowPermissionGate {
                DashboardPermissionOnboardingView(viewModel: viewModel)
            } else {
                dashboardView
            }
        }
        .frame(minWidth: 1080, minHeight: 760)
        .task {
            await viewModel.loadWindows()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }

            Task {
                await viewModel.handleAppDidBecomeActive()
            }
        }
    }

    private var dashboardView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DashboardHeroSection(viewModel: viewModel)

                    if viewModel.shouldShowPermissionBanner {
                        DashboardPermissionBanner(viewModel: viewModel)
                    }

                    HStack(alignment: .top, spacing: 20) {
                        DashboardWindowSelectionCard(
                            viewModel: viewModel,
                            height: windowSelectionCardHeight
                        )
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity)

                        DashboardPreviewSection(viewModel: viewModel)
                            .frame(width: 360)

                        DashboardCaptureStudioCard(viewModel: viewModel)
                            .frame(width: 360)
                    }
                }
                .padding(28)
            }
            .navigationTitle("Capture In Picture")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentViewModel())
}
