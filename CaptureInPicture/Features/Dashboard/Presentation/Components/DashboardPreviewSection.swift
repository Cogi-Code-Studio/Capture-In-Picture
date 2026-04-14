import AppKit
import SwiftUI

struct DashboardPreviewSection: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(.title2.weight(.semibold))

                    Text("Use one-shot capture to test framing, then move into repeat capture when the setup looks right.")
                        .foregroundStyle(.secondary)
                }

                if viewModel.lastSavedURL != nil {
                    HStack {
                        Spacer(minLength: 0)

                        Button("Reveal Capture") {
                            viewModel.revealLastSavedCapture()
                        }
                    }
                }
            }

            if let previewImage = viewModel.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Your latest captured window will appear here.")
                                .font(.headline)

                            Text("Run a one-shot capture to quickly check framing and crop.")
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            if let lastSavedURL = viewModel.lastSavedURL {
                Text(lastSavedURL.path)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .dashboardCard()
    }
}
