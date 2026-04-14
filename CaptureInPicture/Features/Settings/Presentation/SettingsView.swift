//
//  SettingsView.swift
//  CaptureInPicture
//
//  Created by Codex on 3/23/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: ContentViewModel

    var body: some View {
        TabView {
            SettingsGeneralTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            SettingsCaptureTab(viewModel: viewModel)
                .tabItem {
                    Label("Capture", systemImage: "slider.horizontal.3")
                }

            SettingsMacroTab(viewModel: viewModel)
                .tabItem {
                    Label("Macro", systemImage: "square.stack.3d.up")
                }

            SettingsSupportTab(viewModel: viewModel)
                .tabItem {
                    Label("Support", systemImage: "questionmark.circle")
                }
        }
        .frame(width: 900, height: 620)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ContentViewModel())
}
