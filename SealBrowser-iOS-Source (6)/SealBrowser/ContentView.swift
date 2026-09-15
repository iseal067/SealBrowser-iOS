import SwiftUI
import WebKit
import UIKit

private enum SealUI {
    static let accent = Color(red: 10/255, green: 132/255, blue: 255/255)
    static let background = Color.black
    static let chrome = Color(red: 18/255, green: 18/255, blue: 20/255)
    static let surface = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let surface2 = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let border = Color(red: 56/255, green: 56/255, blue: 58/255)
    static let text = Color(red: 242/255, green: 242/255, blue: 247/255)
    static let muted = Color(red: 142/255, green: 142/255, blue: 147/255)
}

struct ContentView: View {
    @StateObject private var browser = BrowserStore()
    @State private var showingTabs = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let tab = browser.selectedTab {
                BrowserPage(tab: tab, browser: browser, showingTabs: $showingTabs)
                    .id(tab.id)
            } else {
                SealUI.background.ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showingTabs) {
            TabSwitcher(browser: browser, isPresented: $showingTabs)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                browser.saveSession()
            }
        }
    }
}

private struct BrowserPage: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    @Binding var showingTabs: Bool

    @FocusState private var addressFocused: Bool
    @State private var addressText = ""
    @State private var showingMenu = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    WebViewContainer(tab: tab)
                        .background(SealUI.background)

                    if tab.isLoading {
                        ProgressView(value: max(0.03, tab.progress))
                            .progressViewStyle(.linear)
                            .tint(SealUI.accent)
                            .frame(height: 2)
                    }
                }

                bottomChrome
            }
            .background(SealUI.background)

            if showingMenu {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showingMenu = false
                        }
                    }

                VStack {
                    Spacer()
                    BrowserMenuPanel(
                        tab: tab,
                        browser: browser,
                        dismiss: {
                            withAnimation(.easeOut(duration: 0.16)) {
                                showingMenu = false
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            addressText = tab.address.isEmpty ? "" : tab.displayHost
        }
        .onChange(of: tab.address) { _ in
            if !addressFocused {
                addressText = tab.address.isEmpty ? "" : tab.displayHost
            }
        }
        .onChange(of: addressFocused) { focused in
            if focused {
                addressText = tab.address
            } else {
                addressText = tab.address.isEmpty ? "" : tab.displayHost
            }
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SealUI.surface2)
                .frame(height: 1)

            VStack(spacing: 5) {
                addressBar
                toolbar
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 6)
        }
        .background(SealUI.chrome)
    }

    private var addressBar: some View {
        HStack(spacing: 6) {
            Button {
                addressText = tab.address
                addressFocused = true
            } label: {
                Image(systemName: tab.address.isEmpty ? "magnifyingglass" : "lock.fill")
                    .font(.system(size: tab.address.isEmpty ? 14 : 10.5, weight: .semibold))
                    .foregroundStyle(SealUI.muted)
                    .frame(width: 24, height: 42)
            }
            .buttonStyle(.plain)

            TextField("Search or enter website", text: $addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($addressFocused)
                .font(.system(size: 15, weight: addressFocused ? .regular : .medium))
                .foregroundStyle(tab.address.isEmpty && !addressFocused ? SealUI.muted : SealUI.text)
                .tint(SealUI.accent)
                .lineLimit(1)
                .onSubmit {
                    let destination = addressText
                    tab.open(destination)
                    addressFocused = false
                }

            Button {
                if addressFocused {
                    if addressText.isEmpty {
                        addressFocused = false
                    } else {
                        addressText = ""
                    }
                } else {
                    tab.reloadOrStop()
                }
            } label: {
                Image(systemName: addressFocused ? (addressText.isEmpty ? "xmark" : "xmark.circle.fill") : (tab.isLoading ? "xmark" : "arrow.clockwise"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SealUI.muted)
                    .frame(width: 38, height: 42)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 4)
        .frame(height: 42)
        .background(SealUI.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            ChromeButton(symbol: "chevron.left", enabled: tab.canGoBack, action: tab.goBack)
            ChromeButton(symbol: "chevron.right", enabled: tab.canGoForward, action: tab.goForward)

            ChromeButton(symbol: "plus") {
                browser.newTab()
            }

            Button {
                tab.capturePreview()
                showingTabs = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(SealUI.accent, lineWidth: 1.35)
                        .frame(width: 24, height: 22)
                    Text("\(max(1, browser.tabs.count))")
                        .font(.system(size: browser.tabs.count > 9 ? 8 : 10, weight: .bold))
                        .foregroundStyle(SealUI.accent)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.plain)

            Button {
                addressFocused = false
                withAnimation(.easeOut(duration: 0.16)) {
                    showingMenu = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(SealUI.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 45)
    }
}

private struct ChromeButton: View {
    let symbol: String
    var enabled: Bool = true
    let action: () -> Void

    init(symbol: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.symbol = symbol
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(enabled ? SealUI.accent : SealUI.muted.opacity(0.28))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct BrowserMenuPanel: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var browser: BrowserStore
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MenuRow(title: "New Tab") {
                dismiss()
                browser.newTab()
            }
            Divider().overlay(SealUI.border).padding(.horizontal, 12)

            MenuRow(title: "Start Page") {
                dismiss()
                tab.home()
            }
            Divider().overlay(SealUI.border).padding(.horizontal, 12)

            MenuRow(title: tab.isLoading ? "Stop Loading" : "Reload") {
                dismiss()
                tab.reloadOrStop()
            }
            Divider().overlay(SealUI.border).padding(.horizontal, 12)

            MenuRow(title: "Copy Address", enabled: !tab.address.isEmpty) {
                UIPasteboard.general.string = tab.address
                dismiss()
            }

            if let url = URL(string: tab.address), !tab.address.isEmpty {
                Divider().overlay(SealUI.border).padding(.horizontal, 12)
                ShareLink(item: url) {
                    HStack {
                        Text("Share Page")
                            .font(.system(size: 16))
                            .foregroundStyle(SealUI.text)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(SealUI.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SealUI.border, lineWidth: 1)
        }
    }
}

private struct MenuRow: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(enabled ? SealUI.text : SealUI.muted.opacity(0.45))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct TabSwitcher: View {
    @ObservedObject var browser: BrowserStore
    @Binding var isPresented: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Tabs")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(SealUI.text)

                Spacer()

                Button {
                    browser.newTab()
                    isPresented = false
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(SealUI.accent)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Button("Done") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SealUI.accent)
                .frame(width: 62, height: 44)
                .buttonStyle(.plain)
            }
            .frame(height: 58)
            .padding(.horizontal, 14)
            .padding(.top, 4)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(browser.tabs) { tab in
                        TabCard(
                            tab: tab,
                            selected: browser.selectedTabID == tab.id,
                            onOpen: {
                                browser.selectTab(tab.id)
                                isPresented = false
                            },
                            onClose: {
                                browser.closeTab(tab.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
        .background(SealUI.background.ignoresSafeArea())
        .onAppear {
            browser.captureTabPreviews()
        }
    }
}

private struct TabCard: View {
    @ObservedObject var tab: BrowserTab
    let selected: Bool
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                SealUI.surface2

                if let image = tab.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SealUI.text)
                        .frame(width: 31, height: 31)
                        .background(SealUI.surface2.opacity(0.88))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(5)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SealUI.text)
                    .lineLimit(1)
                    .frame(height: 24, alignment: .leading)

                Text(tab.address.isEmpty ? "New Tab" : tab.displayHost)
                    .font(.system(size: 11))
                    .foregroundStyle(SealUI.muted)
                    .lineLimit(1)
                    .frame(height: 20, alignment: .leading)
            }
            .padding(.horizontal, 3)
            .padding(.top, 7)
        }
        .padding(7)
        .frame(height: 217, alignment: .top)
        .background(SealUI.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(selected ? SealUI.accent : SealUI.border, lineWidth: selected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onTapGesture(perform: onOpen)
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
