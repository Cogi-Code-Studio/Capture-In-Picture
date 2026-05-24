import AppKit
import SwiftUI

struct DashboardBackgroundView: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}
