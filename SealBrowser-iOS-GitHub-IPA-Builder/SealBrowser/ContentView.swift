import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var browser = BrowserStore()
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            toolbar
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.46, blue: 1.0), Color(red: 0.34, green: 0.83, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            WebViewContainer(browser: browser)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(Color(red: 0.02, green: 0.05, blue: 0.11))
        .onAppear {
            if browser.webView.url == nil { browser.home() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [Color(red: 0.02, green: 0.34, blue: 0.85), Color(red: 0.18, green: 0.73, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("S")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Seal Browser")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(browser.title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.55, green: 0.69, blue: 0.84))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(red: 0.025, green: 0.07, blue: 0.15))
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            ToolbarIcon(symbol: "chevron.left", enabled: browser.canGoBack, action: browser.goBack)
            ToolbarIcon(symbol: "chevron.right", enabled: browser.canGoForward, action: browser.goForward)
            ToolbarIcon(symbol: "arrow.clockwise", action: browser.reload)
            ToolbarIcon(symbol: "house", action: browser.home)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(red: 0.44, green: 0.74, blue: 1.0))
                TextField("Search or enter a URL", text: $browser.address)
                    .focused($addressFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .foregroundStyle(.white)
                    .onSubmit {
                        browser.open(browser.address)
                        addressFocused = false
                    }
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Color(red: 0.02, green: 0.08, blue: 0.17))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.10, green: 0.39, blue: 0.70), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(red: 0.025, green: 0.07, blue: 0.15))
    }
}

private struct ToolbarIcon: View {
    let symbol: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 40)
                .foregroundStyle(enabled ? Color(red: 0.70, green: 0.86, blue: 1.0) : Color(red: 0.25, green: 0.36, blue: 0.49))
                .background(Color(red: 0.035, green: 0.12, blue: 0.24))
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let browser: BrowserStore

    func makeUIView(context: Context) -> WKWebView {
        browser.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
