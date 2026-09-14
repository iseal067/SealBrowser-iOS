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
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
      <meta name="theme-color" content="#090d14">
      <style>
        :root{color-scheme:dark;--bg:#090d14;--card:#111824;--card2:#151e2c;--line:#223048;--blue:#287cff;--text:#f5f7fb;--muted:#8290a5}
        *{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
        html,body{margin:0;min-height:100%;background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",sans-serif;color:var(--text)}
        body{min-height:100vh;padding:max(34px,env(safe-area-inset-top)) 18px max(135px,env(safe-area-inset-bottom));}
        .page{max-width:620px;margin:0 auto}
        .top{display:flex;align-items:center;justify-content:space-between;padding:8px 2px 40px}
        .brand{display:flex;align-items:center;gap:10px;font-size:15px;font-weight:650;letter-spacing:-.01em}
        .mark{width:30px;height:30px;border-radius:9px;display:grid;place-items:center;background:var(--blue);color:white;font-weight:800;font-size:15px}
        .date{font-size:12px;color:var(--muted)}
        .hello{font-size:34px;line-height:1.06;font-weight:720;letter-spacing:-.04em;margin:0 0 8px}
        .sub{font-size:15px;line-height:1.45;color:var(--muted);margin:0 0 24px}
        .search{height:52px;display:flex;align-items:center;gap:11px;background:var(--card);border:1px solid var(--line);border-radius:15px;padding:0 14px;margin-bottom:26px}
        .search svg{width:18px;height:18px;fill:none;stroke:#8ea0b8;stroke-width:2;stroke-linecap:round}
        .search input{appearance:none;border:0;outline:0;background:transparent;color:var(--text);font:inherit;font-size:15px;flex:1;min-width:0}
        .search input::placeholder{color:#6e7c90}
        .section{font-size:12px;font-weight:650;color:#8e9aae;text-transform:uppercase;letter-spacing:.08em;margin:0 0 10px 2px}
        .links{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
        .link{display:flex;align-items:center;gap:12px;min-height:66px;text-decoration:none;color:var(--text);padding:12px;background:var(--card);border:1px solid var(--line);border-radius:15px}
        .icon{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;background:var(--card2);font-weight:750;font-size:14px;color:#dfe8f7}
        .meta{min-width:0}.name{font-size:14px;font-weight:650;line-height:1.2}.host{font-size:11px;color:var(--muted);margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .tip{margin-top:26px;padding:14px 15px;background:#0d1420;border:1px solid #1b2a40;border-radius:14px;color:#74839a;font-size:12px;line-height:1.45}
        @media(min-width:520px){.links{grid-template-columns:repeat(4,minmax(0,1fr))}.link{display:block}.icon{margin-bottom:15px}.top{padding-top:24px}.hello{font-size:42px}}
      </style>
    </head>
    <body>
      <main class="page">
        <header class="top">
          <div class="brand"><div class="mark">S</div><span>Seal</span></div>
          <div class="date" id="date"></div>
        </header>

        <h1 class="hello" id="hello">Good evening.</h1>
        <p class="sub">Where do you want to go?</p>

        <form class="search" action="https://www.google.com/search" method="get">
          <input type="hidden" name="hl" value="en">
          <input type="hidden" name="gl" value="gb">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><path d="m20 20-3.5-3.5"></path></svg>
          <input name="q" autocomplete="off" autocapitalize="none" placeholder="Search the web" aria-label="Search the web">
        </form>

        <div class="section">Quick links</div>
        <div class="links">
          <a class="link" href="https://www.youtube.com"><div class="icon">YT</div><div class="meta"><div class="name">YouTube</div><div class="host">youtube.com</div></div></a>
          <a class="link" href="https://www.roblox.com"><div class="icon">R</div><div class="meta"><div class="name">Roblox</div><div class="host">roblox.com</div></div></a>
          <a class="link" href="https://discord.com/app"><div class="icon">D</div><div class="meta"><div class="name">Discord</div><div class="host">discord.com</div></div></a>
          <a class="link" href="https://www.google.com/?hl=en&gl=gb"><div class="icon">G</div><div class="meta"><div class="name">Google</div><div class="host">google.com</div></div></a>
        </div>

        <div class="tip">Tip: hold a tab in the tab switcher for extra options.</div>
      </main>
      <script>
        (() => {
          const d = new Date();
          const h = d.getHours();
          const greeting = h < 12 ? 'Good morning.' : h < 18 ? 'Good afternoon.' : 'Good evening.';
          document.getElementById('hello').textContent = greeting;
          document.getElementById('date').textContent = d.toLocaleDateString('en-GB',{day:'numeric',month:'short'});
        })();
      </script>
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
