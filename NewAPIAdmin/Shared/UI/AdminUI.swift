import SwiftUI

extension Color {
    static var adminBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.gray.opacity(0.08)
        #endif
    }

    static var adminSurface: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    static var adminStroke: Color { Color.primary.opacity(0.06) }
}

extension View {
    func adminScreenBackground() -> some View {
        background(Color.adminBackground)
    }

    func adminListChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.adminBackground)
            .listStyle(.insetGrouped)
    }

    func adminFormChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.adminBackground)
    }
}

struct AdminSurfaceCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 18

    init(cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.adminSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.adminStroke, lineWidth: 1)
            )
    }
}
