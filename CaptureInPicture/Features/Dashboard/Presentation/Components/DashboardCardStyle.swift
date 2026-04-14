import SwiftUI

private struct DashboardCardModifier: ViewModifier {
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(highlighted ? 28 : 22)
            .background {
                RoundedRectangle(cornerRadius: highlighted ? 30 : 28, style: .continuous)
                    .fill(highlighted ? .thinMaterial : .regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: highlighted ? 30 : 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(highlighted ? 0.34 : 0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(highlighted ? 0.10 : 0.07), radius: highlighted ? 24 : 18, y: 10)
    }
}

extension View {
    func dashboardCard(highlighted: Bool = false) -> some View {
        modifier(DashboardCardModifier(highlighted: highlighted))
    }
}
