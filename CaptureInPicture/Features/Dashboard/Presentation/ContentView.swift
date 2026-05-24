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

    var body: some View {
        ZStack {
            DashboardBackgroundView()

            dashboardView

            if viewModel.isShowingPermissionOnboarding {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                DashboardPermissionOnboardingView(viewModel: viewModel)
                    .padding(32)
                    .frame(maxWidth: 820)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(minWidth: 1080, minHeight: 760)
        .animation(.snappy(duration: 0.22), value: viewModel.isShowingPermissionOnboarding)
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
            VStack(spacing: 0) {
                DashboardHeroSection(viewModel: viewModel)

                Divider()

                HStack(spacing: 0) {
                    DashboardPreviewSection(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    ScrollView {
                        DashboardCaptureStudioCard(viewModel: viewModel)
                            .padding(20)
                    }
                    .frame(width: 360)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
