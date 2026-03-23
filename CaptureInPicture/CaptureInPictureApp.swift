//
//  CaptureInPictureApp.swift
//  CaptureInPicture
//
//  Created by RyuWoong on 3/20/26.
//

import SwiftUI

@main
struct CaptureInPictureApp: App {
    @StateObject private var viewModel = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 1180, height: 820)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
