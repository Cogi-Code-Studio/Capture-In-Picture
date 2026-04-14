import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let document = PrivacyPolicyDocument.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.effectiveDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(document.introduction)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.headline)

                            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(document.contactTitle)
                            .font(.headline)

                        Text(document.contactDescription)
                            .fixedSize(horizontal: false, vertical: true)

                        Link("admin@cogicode.com", destination: URL(string: "mailto:admin@cogicode.com")!)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                .padding(24)
            }
            .navigationTitle(document.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(document.closeButtonTitle) {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .textSelection(.enabled)
    }
}

#Preview {
    PrivacyPolicyView()
}
