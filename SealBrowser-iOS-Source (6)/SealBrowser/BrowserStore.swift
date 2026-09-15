import Foundation
import Combine
import WebKit
import UIKit

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
    @Published var previewImage: UIImage?

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
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        // Media settings used by YouTube, YouTube Shorts and other HTML5 video sites.
        // On iPhone, inline playback is not reliably enabled unless we opt in.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true

        // Some sites dynamically replace their <video> elements (YouTube Shorts does this
        // while swiping). Keep the elements configured for inline playback as they appear.
        let mediaCompatibilityScript = WKUserScript(
            source: #"""
            (() => {
              const patchVideo = (video) => {
                try {
                  video.setAttribute('playsinline', '');
                  video.setAttribute('webkit-playsinline', '');
                  video.playsInline = true;
                } catch (_) {}
              };

              const patchAll = (root) => {
                if (!root) return;
                if (root.tagName === 'VIDEO') patchVideo(root);
                if (root.querySelectorAll) root.querySelectorAll('video').forEach(patchVideo);
              };

              patchAll(document);
              document.addEventListener('DOMContentLoaded', () => patchAll(document), { once: true });

              const observer = new MutationObserver((changes) => {
                for (const change of changes) {
                  for (const node of change.addedNodes || []) {
                    if (node && node.nodeType === 1) patchAll(node);
                  }
                }
              });

              const start = () => {
                if (document.documentElement) {
                  observer.observe(document.documentElement, { childList: true, subtree: true });
                }
              };
              if (document.documentElement) start();
              else document.addEventListener('DOMContentLoaded', start, { once: true });
            })();
            """#,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(mediaCompatibilityScript)

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
            destination = "https://www.google.com/search?hl=en&gl=gb&q=\(encoded)"
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

    func capturePreview() {
        guard webView.bounds.width > 0, webView.bounds.height > 0 else { return }
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = false
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                self?.previewImage = image
            }
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
    <html lang="en-GB">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
      <meta name="theme-color" content="#000000">
      <style>
        :root { color-scheme: dark; --bg:#000; --surface:#1c1c1e; --surface2:#2c2c2e; --line:#38383a; --text:#f2f2f7; --muted:#8e8e93; --blue:#0a84ff; }
        * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
        html,body { margin:0; min-height:100%; background:var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",sans-serif; }
        body { padding:34px 20px 130px; }
        main { max-width:640px; margin:0 auto; }
        header { display:flex; align-items:flex-end; justify-content:space-between; margin:20px 2px 34px; }
        h1 { margin:0; font-size:30px; line-height:1; font-weight:700; letter-spacing:-.8px; }
        .small { font-size:13px; color:var(--muted); }
        .search { display:flex; align-items:center; height:50px; margin-bottom:34px; padding:0 14px; border-radius:12px; background:var(--surface); }
        .search svg { width:17px; height:17px; margin-right:10px; fill:none; stroke:var(--muted); stroke-width:2; stroke-linecap:round; }
        .search input { width:100%; border:0; outline:0; background:transparent; color:var(--text); font:inherit; font-size:16px; }
        .search input::placeholder { color:var(--muted); }
        .label { margin:0 2px 10px; color:var(--muted); font-size:12px; font-weight:600; letter-spacing:.02em; }
        .favorites { overflow:hidden; border-radius:12px; background:var(--surface); }
        .favorite { min-height:58px; display:flex; align-items:center; gap:12px; padding:9px 13px; color:var(--text); text-decoration:none; border-bottom:1px solid var(--line); }
        .favorite:last-child { border-bottom:0; }
        .badge { width:34px; height:34px; display:grid; place-items:center; border-radius:9px; background:var(--surface2); color:#fff; font-size:13px; font-weight:700; }
        .name { font-size:15px; font-weight:500; }
        .host { margin-top:2px; color:var(--muted); font-size:11px; }
        .chevron { margin-left:auto; color:#636366; font-size:20px; font-weight:300; }
      </style>
    </head>
    <body>
      <main>
        <header>
          <h1>Seal</h1>
          <span class="small">New Tab</span>
        </header>

        <form class="search" action="https://www.google.com/search" method="get">
          <input type="hidden" name="hl" value="en">
          <input type="hidden" name="gl" value="gb">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="m20 20-3.5-3.5"></path></svg>
          <input name="q" autocomplete="off" autocapitalize="none" placeholder="Search or enter website" aria-label="Search or enter website">
        </form>

        <div class="label">FAVOURITES</div>
        <div class="favorites">
          <a class="favorite" href="https://www.youtube.com"><div class="badge">YT</div><div><div class="name">YouTube</div><div class="host">youtube.com</div></div><div class="chevron">›</div></a>
          <a class="favorite" href="https://www.google.com/?hl=en&amp;gl=gb"><div class="badge">G</div><div><div class="name">Google</div><div class="host">google.com</div></div><div class="chevron">›</div></a>
          <a class="favorite" href="https://www.roblox.com"><div class="badge">R</div><div><div class="name">Roblox</div><div class="host">roblox.com</div></div><div class="chevron">›</div></a>
          <a class="favorite" href="https://discord.com/app"><div class="badge">D</div><div><div class="name">Discord</div><div class="host">discord.com</div></div><div class="chevron">›</div></a>
        </div>
      </main>
    </body>
    </html>
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

    func captureTabPreviews() {
        for tab in tabs {
            tab.capturePreview()
        }
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
