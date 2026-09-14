import Foundation
import Combine
import WebKit

struct SavedBrowserTab: Codable {
    let id: UUID
    let title: String
    let url: String?
}

private struct SavedBrowserSession: Codable {
    let tabs: [SavedBrowserTab]
    let selectedTabID: UUID?
}

final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id: UUID

    @Published var address: String = ""
    @Published var title: String = "New Tab"
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0

    let webView: WKWebView

    var onStateChange: (() -> Void)?
    var onOpenNewTab: ((URL) -> Void)?

    private var progressObservation: NSKeyValueObservation?

    init(id: UUID = UUID(), restoredURL: String? = nil, restoredTitle: String? = nil) {
        self.id = id

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        if let restoredTitle, !restoredTitle.isEmpty {
            title = restoredTitle
        }

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progress = webView.estimatedProgress
            }
        }

        if let restoredURL, let url = URL(string: restoredURL) {
            address = restoredURL
            webView.load(URLRequest(url: url))
        } else {
            home()
        }
    }

    deinit {
        progressObservation?.invalidate()
    }

    var persistentURL: String? {
        guard let url = webView.url else { return nil }
        if url.host == "seal.local" || url.absoluteString == "about:blank" { return nil }
        return url.absoluteString
    }

    var displayHost: String {
        guard let url = webView.url, url.host != "seal.local" else { return "New Tab" }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? "Web"
    }

    func home() {
        address = ""
        title = "New Tab"
        webView.loadHTMLString(Self.startPage, baseURL: URL(string: "https://seal.local"))
        syncState()
        onStateChange?()
    }

    func open(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            home()
            return
        }

        let destination: String
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            destination = trimmed
        } else if !trimmed.contains(" ") && trimmed.contains(".") {
            destination = "https://\(trimmed)"
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            destination = "https://www.google.com/search?q=\(encoded)"
        }

        guard let url = URL(string: destination) else { return }
        address = destination
        webView.load(URLRequest(url: url))
        onStateChange?()
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func reloadOrStop() {
        if isLoading {
            webView.stopLoading()
            isLoading = false
        } else {
            webView.reload()
        }
    }

    private func syncState() {
        DispatchQueue.main.async {
            self.canGoBack = self.webView.canGoBack
            self.canGoForward = self.webView.canGoForward
            self.isLoading = self.webView.isLoading

            if let url = self.webView.url,
               url.host != "seal.local",
               url.absoluteString != "about:blank" {
                self.address = url.absoluteString
            } else if self.webView.url?.host == "seal.local" {
                self.address = ""
            }

            if let pageTitle = self.webView.title, !pageTitle.isEmpty, self.webView.url?.host != "seal.local" {
                self.title = pageTitle
            } else if self.webView.url?.host == "seal.local" {
                self.title = "New Tab"
            }

            self.onStateChange?()
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        syncState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        syncState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        progress = 1
        syncState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        syncState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        syncState()
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            onOpenNewTab?(url)
        }
        return nil
    }

    private static let startPage = #"""
    <!doctype html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
    <meta name="theme-color" content="#020813">
    <style>
    *{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
    body{margin:0;min-height:100vh;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#f7fbff;background:radial-gradient(circle at 74% 6%,#006dff55,transparent 30%),radial-gradient(circle at 8% 82%,#00bfff2b,transparent 34%),linear-gradient(155deg,#020711 0%,#06162d 52%,#03101e 100%);padding:max(34px,env(safe-area-inset-top)) 20px max(120px,env(safe-area-inset-bottom));overflow-x:hidden}
    .wrap{max-width:620px;margin:0 auto}.hero{padding-top:7vh;text-align:center}.logo{width:82px;height:82px;border-radius:27px;margin:0 auto 22px;display:grid;place-items:center;font-size:34px;font-weight:900;letter-spacing:-.06em;background:linear-gradient(145deg,#0866ff,#00a9ff 65%,#8ce7ff);box-shadow:0 0 60px #087cff66,0 20px 55px #0009;border:1px solid #99e8ff99}.brand{font-size:12px;letter-spacing:.29em;text-transform:uppercase;color:#77a9d8}.title{font-size:41px;font-weight:850;line-height:1.04;letter-spacing:-.04em;margin:14px 0 11px}.grad{background:linear-gradient(90deg,#a7ecff,#31a6ff,#6f88ff);-webkit-background-clip:text;color:transparent}.sub{font-size:15px;color:#87a8c8;line-height:1.55;max-width:390px;margin:0 auto}.searchhint{margin:30px 0 17px;padding:17px 18px;border-radius:20px;background:linear-gradient(180deg,#0a1d38e8,#071429e8);border:1px solid #1b5f9e;box-shadow:inset 0 1px #ffffff10,0 15px 42px #0007;color:#b8dcff;text-align:left}.searchhint b{color:#fff}.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}.tile{position:relative;overflow:hidden;padding:18px 16px;border-radius:20px;text-decoration:none;color:#eaf6ff;text-align:left;background:linear-gradient(155deg,#0b203cdd,#07162bdd);border:1px solid #174e82;box-shadow:0 15px 30px #0004}.tile:before{content:'';position:absolute;width:70px;height:70px;border-radius:50%;right:-25px;top:-28px;background:#168cff30;filter:blur(8px)}.ico{width:34px;height:34px;border-radius:11px;background:#0c4f9a;display:grid;place-items:center;font-weight:800;margin-bottom:17px;border:1px solid #3a8bd2}.tile b{font-size:15px}.tile small{display:block;color:#7298bd;margin-top:5px;font-size:12px}.foot{text-align:center;color:#4f769c;font-size:11px;letter-spacing:.16em;text-transform:uppercase;margin-top:28px}
    @media(min-width:540px){.grid{grid-template-columns:repeat(4,1fr)}.hero{padding-top:12vh}}
    </style>
    </head>
    <body><div class="wrap"><div class="hero"><div class="logo">S</div><div class="brand">Seal Browser</div><div class="title">Browse in<br><span class="grad">electric blue.</span></div><div class="sub">Fast, clean and built for your phone. Your tabs will be waiting when you come back.</div></div><div class="searchhint"><b>Search from the bar below</b><br><span style="font-size:12px;color:#6f95ba">Enter a website, question or search.</span></div><div class="grid"><a class="tile" href="https://www.google.com"><div class="ico">G</div><b>Google</b><small>Search the web</small></a><a class="tile" href="https://www.youtube.com"><div class="ico">▶</div><b>YouTube</b><small>Watch videos</small></a><a class="tile" href="https://www.roblox.com"><div class="ico">R</div><b>Roblox</b><small>Jump into games</small></a><a class="tile" href="https://discord.com/app"><div class="ico">D</div><b>Discord</b><small>Open Discord</small></a></div><div class="foot">Fast • Clean • Yours</div></div></body></html>
    """#
}

final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var selectedTabID: UUID?

    private let sessionKey = "sealBrowser.savedSession.v2"
    private var isRestoring = false

    init() {
        restoreSession()
        if tabs.isEmpty {
            newTab()
        }
    }

    var selectedTab: BrowserTab? {
        guard let selectedTabID else { return tabs.first }
        return tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first
    }

    var selectedIndex: Int {
        guard let selectedTabID, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return 0 }
        return index
    }

    @discardableResult
    func newTab(url: URL? = nil, select: Bool = true) -> BrowserTab {
        let tab = makeTab(id: UUID(), restoredURL: url?.absoluteString, restoredTitle: nil)
        tabs.append(tab)
        if select || selectedTabID == nil {
            selectedTabID = tab.id
        }
        saveSession()
        return tab
    }

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
        saveSession()
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)

        if tabs.isEmpty {
            newTab()
            return
        }

        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
        }
        saveSession()
    }

    func closeOtherTabs(keeping id: UUID) {
        guard let kept = tabs.first(where: { $0.id == id }) else { return }
        tabs = [kept]
        selectedTabID = id
        saveSession()
    }

    func saveSession() {
        guard !isRestoring else { return }
        let savedTabs = tabs.prefix(30).map {
            SavedBrowserTab(id: $0.id, title: $0.title, url: $0.persistentURL)
        }
        let session = SavedBrowserSession(tabs: Array(savedTabs), selectedTabID: selectedTabID)
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionKey)
    }

    private func restoreSession() {
        isRestoring = true
        defer { isRestoring = false }

        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(SavedBrowserSession.self, from: data),
              !session.tabs.isEmpty else {
            return
        }

        tabs = session.tabs.prefix(30).map { saved in
            makeTab(id: saved.id, restoredURL: saved.url, restoredTitle: saved.title)
        }

        if let selected = session.selectedTabID, tabs.contains(where: { $0.id == selected }) {
            selectedTabID = selected
        } else {
            selectedTabID = tabs.first?.id
        }
    }

    private func makeTab(id: UUID, restoredURL: String?, restoredTitle: String?) -> BrowserTab {
        let tab = BrowserTab(id: id, restoredURL: restoredURL, restoredTitle: restoredTitle)
        tab.onStateChange = { [weak self] in
            self?.saveSession()
        }
        tab.onOpenNewTab = { [weak self] url in
            DispatchQueue.main.async {
                self?.newTab(url: url)
            }
        }
        return tab
    }
}
