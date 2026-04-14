import AppKit
import SwiftUI

struct DashboardBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor),
                Color.accentColor.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 380, height: 380)
                .blur(radius: 20)
                .offset(x: -60, y: -90)
        }
        .ignoresSafeArea()
    }
}
