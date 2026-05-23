import SwiftUI

struct PlaceholderFeatureView: View {
    let title: String
    let description: String

    var body: some View {
        AdminSurfaceCard {
            VStack(spacing: 16) {
                Image(systemName: "hammer")
                    .font(Font.system(size: 40, weight: .semibold))
                    .foregroundColor(Color.accentColor)
                Text(title)
                    .font(Font.title3.bold())
                Text(description)
                    .font(Font.body)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(TextAlignment.center)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}
