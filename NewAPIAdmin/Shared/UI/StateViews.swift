import SwiftUI

struct LoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title)
                .foregroundColor(Color.secondary)
        }
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage = "tray"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(Font.largeTitle)
                .foregroundColor(Color.secondary)
            Text(title)
                .font(Font.headline)
            Text(message)
                .font(Font.body)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(TextAlignment.center)
        }
        .padding()
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(Font.largeTitle)
                .foregroundColor(Color.orange)
            Text(message)
                .multilineTextAlignment(TextAlignment.center)
                .foregroundColor(Color.secondary)
            if let retry {
                Button("重试", action: retry)
            }
        }
        .padding()
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }
}

struct PermissionStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(Font.largeTitle)
                .foregroundColor(Color.orange)
            Text("权限不足")
                .font(Font.headline)
            Text(message)
                .font(Font.body)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(TextAlignment.center)
        }
        .padding()
        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
    }
}
