import SwiftUI
import WebKit

/// Loads the game page from the web, keeps a copy on the device, and falls back to that copy
/// (or the one bundled in the app) when there is no internet.
/// The page is always shown with the same web address as its origin, so Flora's saved progress
/// (stars, collection) stays the same whether the page came from the web or from the copy.
final class GameController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    private var lastLoad = Date.distantPast
    private var backgroundedAt: Date?

    private var savedCopyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("game.html")
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()              // keeps progress between launches
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.06, green: 0.11, blue: 0.10, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // the page handles the notch/home bar itself
        webView.allowsLinkPreview = false
        super.init()
        webView.navigationDelegate = self
        try? FileManager.default.createDirectory(at: savedCopyURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        load()
    }

    func wentToBackground() { backgroundedAt = Date() }

    func refreshIfStale() {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        if Date().timeIntervalSince(since) > Config.refreshAfter { load() }
    }

    func load() {
        lastLoad = Date()
        // Show what we have straight away, then swap in the newest version if it differs.
        let local = localHTML()
        if let local { show(local) }

        var comps = URLComponents(url: Config.gameURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            guard let data,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8),
                  html.contains("Fraction Quest") else { return }   // offline or bad response: keep the local copy
            if html == local { return }                              // already showing the newest version
            try? data.write(to: self.savedCopyURL, options: .atomic)
            DispatchQueue.main.async { self.show(html) }
        }.resume()
    }

    private func localHTML() -> String? {
        if let saved = try? String(contentsOf: savedCopyURL, encoding: .utf8) { return saved }
        if let bundled = Bundle.main.url(forResource: "game", withExtension: "html") {
            return try? String(contentsOf: bundled, encoding: .utf8)
        }
        return nil
    }

    private func show(_ html: String) {
        webView.loadHTMLString(html, baseURL: Config.gameURL)
    }

    // Keep Flora inside the game: anything that tries to open another website is ignored.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
}

struct GameView: UIViewRepresentable {
    @ObservedObject var game: GameController
    func makeUIView(context: Context) -> WKWebView { game.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
