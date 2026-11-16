import SwiftUI
import WebKit

/// Shows the quest pages from the website, with offline copies.
///
/// - On launch it shows the saved copy straight away, then downloads docs/manifest.json and every page in it.
///   Pages that changed are saved, and the page on screen is refreshed if it changed.
/// - With no internet it uses the saved copies, or the copies bundled in the app on the very first run.
/// - Every page is shown with its real web address as its origin, so saved progress (stars, collections)
///   is the same whether a page came from the web or from a copy.
/// - Links between quest pages are handled here; links to any other website are ignored.
final class QuestController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    private var currentPage = ""
    private var expectedLoad: URL?
    private var backgroundedAt: Date?

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()              // keeps progress between launches
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.06, green: 0.11, blue: 0.10, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // pages handle the notch/home bar themselves
        webView.allowsLinkPreview = false
        super.init()
        webView.navigationDelegate = self
        show("")
        refreshAll()
    }

    // MARK: lifecycle

    func wentToBackground() { backgroundedAt = Date() }

    func refreshIfStale() {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        if Date().timeIntervalSince(since) > Config.refreshAfter { refreshAll() }
    }

    // MARK: pages

    private func pageURL(_ page: String) -> URL {
        page.isEmpty ? Config.siteURL : URL(string: page, relativeTo: Config.siteURL)!.absoluteURL
    }

    private func fileName(_ page: String) -> String {
        let trimmed = page.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "home" : trimmed.replacingOccurrences(of: "/", with: "_")
    }

    private func savedHTML(_ page: String) -> String? {
        try? String(contentsOf: cacheDir.appendingPathComponent(fileName(page) + ".html"), encoding: .utf8)
    }

    private func localHTML(_ page: String) -> String? {
        if let saved = savedHTML(page) { return saved }
        if let bundled = Bundle.main.url(forResource: fileName(page), withExtension: "html") {
            return try? String(contentsOf: bundled, encoding: .utf8)
        }
        return nil
    }

    private func show(_ page: String) {
        guard let html = localHTML(page) else {
            if !page.isEmpty { show("") }                    // unknown page and offline: go home
            return
        }
        currentPage = page
        let url = pageURL(page)
        expectedLoad = url
        webView.loadHTMLString(html, baseURL: url)
    }

    // MARK: updates

    private func fetch(_ url: URL, completion: @escaping (Data?) -> Void) {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            completion((response as? HTTPURLResponse)?.statusCode == 200 ? data : nil)
        }.resume()
    }

    func refreshAll() {
        fetch(Config.siteURL.appendingPathComponent("manifest.json")) { [weak self] data in
            guard let self, let data,
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pages = manifest["pages"] as? [String] else { return }   // offline: keep the copies
            let group = DispatchGroup()
            var changed = Set<String>()
            let lock = NSLock()
            for page in pages {
                group.enter()
                self.fetch(self.pageURL(page)) { data in
                    defer { group.leave() }
                    guard let data, let html = String(data: data, encoding: .utf8),
                          html.lowercased().contains("<html") else { return }
                    if html == self.savedHTML(page) { return }
                    try? data.write(to: self.cacheDir.appendingPathComponent(self.fileName(page) + ".html"), options: .atomic)
                    lock.lock(); changed.insert(page); lock.unlock()
                }
            }
            group.notify(queue: .main) {
                if changed.contains(self.currentPage) && self.localHTML(self.currentPage) != nil {
                    self.show(self.currentPage)
                }
            }
        }
    }

    // MARK: navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        #if DEBUG
        print("[nav]", action.navigationType.rawValue, url.absoluteString)
        #endif
        if url.scheme == "about" { decisionHandler(.allow); return }

        let withoutFragment = url.absoluteString.components(separatedBy: "#")[0]
        // the page we just asked to show, or a jump within the current page
        if let expected = expectedLoad, withoutFragment == expected.absoluteString {
            decisionHandler(.allow); return
        }

        // a link to another quest page: show it from the copies
        let site = Config.siteURL
        if url.host == site.host, url.path.hasPrefix(site.path) {
            var page = String(url.path.dropFirst(site.path.count))
            while page.hasPrefix("/") { page.removeFirst() }
            if page.hasSuffix("index.html") { page = String(page.dropLast("index.html".count)) }
            if !page.isEmpty, !page.hasSuffix("/") { page += "/" }
            decisionHandler(.cancel)
            DispatchQueue.main.async { self.show(page) }   // start the new load after this one is cancelled
            return
        }
        decisionHandler(.cancel)   // any other website: stay in the app
    }
}

struct QuestView: UIViewRepresentable {
    @ObservedObject var quests: QuestController
    func makeUIView(context: Context) -> WKWebView { quests.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
