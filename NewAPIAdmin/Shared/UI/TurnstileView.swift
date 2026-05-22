import SwiftUI
#if os(iOS)
import WebKit

struct TurnstileView: UIViewRepresentable {
    let siteKey: String
    let onToken: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "turnstile")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        loadTurnstile(webView: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken)
    }

    private func loadTurnstile(webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
            <style>
                body { margin: 0; padding: 16px; display: flex; justify-content: center; align-items: center; background: transparent; }
            </style>
        </head>
        <body>
            <div class="cf-turnstile" data-sitekey="\(siteKey)" data-callback="onSuccess" data-theme="auto"></div>
            <script>
                function onSuccess(token) {
                    window.webkit.messageHandlers.turnstile.postMessage(token);
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://challenges.cloudflare.com"))
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onToken: (String) -> Void

        init(onToken: @escaping (String) -> Void) {
            self.onToken = onToken
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let token = message.body as? String {
                onToken(token)
            }
        }
    }
}
#endif
