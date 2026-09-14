import Foundation
import Combine
import WebKit

final class BrowserStore: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var address = ""
    @Published var title = "New Tab"
    @Published var canGoBack = false
    @Published var canGoForward = false

    let webView: WKWebView

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func home() {
        address = ""
        title = "New Tab"
        webView.loadHTMLString(Self.startPage, baseURL: URL(string: "https://seal.local"))
        syncState()
    }

    func open(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            home()
            return
        }

        let destination: String
        if let url = URL(string: trimmed), let scheme = url.scheme,
           scheme == "http" || scheme == "https" {
            destination = trimmed
        } else if !trimmed.contains(" ") && trimmed.contains(".") {
            destination = "https://\(trimmed)"
        } else {
            destination = "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)"
        }

        guard let url = URL(string: destination) else { return }
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    func reload() {
        webView.reload()
    }

    private func syncState() {
        DispatchQueue.main.async {
            self.canGoBack = self.webView.canGoBack
            self.canGoForward = self.webView.canGoForward
            if let url = self.webView.url, url.host != "seal.local", url.absoluteString != "about:blank" {
                self.address = url.absoluteString
            }
            if let pageTitle = self.webView.title, !pageTitle.isEmpty {
                self.title = pageTitle
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        syncState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        syncState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        syncState()
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    private static let startPage = #"""
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>
    *{box-sizing:border-box}body{margin:0;min-height:100vh;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#f4f9ff;background:radial-gradient(circle at 80% 10%,#087dff55,transparent 34%),radial-gradient(circle at 20% 90%,#00b8ff33,transparent 36%),linear-gradient(145deg,#030816,#071a34 60%,#04101f);display:flex;align-items:center;justify-content:center;padding:32px}.card{width:100%;max-width:560px;text-align:center}.logo{width:76px;height:76px;border-radius:24px;margin:0 auto 22px;display:grid;place-items:center;font-size:38px;font-weight:800;background:linear-gradient(145deg,#075bdc,#14a7ff 65%,#63d7ff);box-shadow:0 0 45px #168cff66;border:1px solid #78ddff88}.eyebrow{font-size:11px;letter-spacing:.27em;color:#78aee3;text-transform:uppercase}.title{font-size:38px;font-weight:800;line-height:1.08;margin:14px 0 10px}.grad{background:linear-gradient(90deg,#68d6ff,#168cff,#7bb5ff);-webkit-background-clip:text;color:transparent}.sub{color:#8aadd2;font-size:15px;line-height:1.5}.search{margin:32px auto 0;background:#07162ddd;border:1px solid #1d5b9b;border-radius:22px;padding:17px 20px;color:#84cfff;box-shadow:0 18px 55px #0008}.tiles{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:18px}.tile{padding:16px;border:1px solid #174878;border-radius:18px;background:#07162dcc;color:#dceeff;text-decoration:none}.tile small{display:block;color:#6f96bd;margin-top:4px}
    </style></head><body><div class="card"><div class="logo">S</div><div class="eyebrow">fast • clean • yours</div><div class="title">Seal Browser<br><span class="grad">Blue Edition</span></div><div class="sub">Use the address bar above to search or enter a website.</div><div class="search">Browse in electric blue.</div><div class="tiles"><a class="tile" href="https://www.google.com"><b>Google</b><small>Search</small></a><a class="tile" href="https://www.youtube.com"><b>YouTube</b><small>Watch</small></a><a class="tile" href="https://www.roblox.com"><b>Roblox</b><small>Play</small></a><a class="tile" href="https://discord.com/app"><b>Discord</b><small>Chat</small></a></div></div></body></html>
    """#
}
