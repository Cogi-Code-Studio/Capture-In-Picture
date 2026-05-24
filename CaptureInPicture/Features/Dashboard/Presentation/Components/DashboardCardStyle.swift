import SwiftUI

private struct DashboardCardModifier: ViewModifier {
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(highlighted ? 20 : 18)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
    }
}

extension View {
    func dashboardCard(highlighted: Bool = false) -> some View {
        modifier(DashboardCardModifier(highlighted: highlighted))
    }
}
