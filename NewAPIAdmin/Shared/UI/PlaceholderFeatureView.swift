import SwiftUI

struct PlaceholderFeatureView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer")
                .font(Font.system(size: 44))
                .foregroundColor(Color.secondary)
            Text(title)
                .font(Font.title2.bold())
            Text(description)
                .font(Font.body)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(TextAlignment.center)
                .padding(Edge.Set.horizontal, 24)
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        .navigationTitle(title)
    }
}
