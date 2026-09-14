import SwiftUI
import WebKit
import UIKit

private enum SealTheme {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.070)
    static let surface = Color(red: 0.058, green: 0.075, blue: 0.105)
    static let surfaceRaised = Color(red: 0.075, green: 0.095, blue: 0.130)
    static let border = Color.white.opacity(0.09)
    static let accent = Color(red: 0.16, green: 0.48, blue: 0.98)
    static let textSecondary = Color.white.opacity(0.58)
}

struct ContentView: View {
    @StateObject private var browser = BrowserStore()
    @State private var showingTabs = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SealTheme.background.ignoresSafeArea()

            if let tab = browser.selectedTab {
                BrowserPage(tab: tab, browser: browser, showingTabs: $showingTabs)
                    .id(tab.id)
            }
        }
        .sheet(isPresented: $showingTabs) {
            TabSwitcher(browser: browser, isPresented: $showingTabs)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    @State private var editingAddress = ""

    var body: some View {
        ZStack(alignment: .top) {
            WebViewContainer(tab: tab)
                .background(SealTheme.background)

            if tab.isLoading {
                ProgressView(value: max(0.05, tab.progress))
                    .progressViewStyle(.linear)
                    .tint(SealTheme.accent)
                    .frame(height: 2)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            browserChrome
        }
        .background(SealTheme.background)
        .onAppear {
            editingAddress = tab.address
        }
        .onChange(of: tab.address) { value in
            if !addressFocused {
                editingAddress = value
            }
        }
        .onChange(of: addressFocused) { focused in
            if focused {
                editingAddress = tab.address
            }
        }
    }

    private var browserChrome: some View {
        VStack(spacing: 7) {
            addressBar
            navigationBar
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            siteIndicator

            Group {
                if addressFocused {
                    TextField("Search or enter website", text: $editingAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .focused($addressFocused)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white)
                        .tint(SealTheme.accent)
                        .onSubmit {
                            tab.open(editingAddress)
                            addressFocused = false
                        }
                } else {
                    VStack(spacing: 1) {
                        Text(tab.address.isEmpty ? "Search or enter website" : tab.displayHost)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if !tab.address.isEmpty, !tab.title.isEmpty, tab.title != tab.displayHost {
                            Text(tab.title)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundStyle(SealTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if addressFocused {
                Button {
                    if editingAddress.isEmpty {
                        addressFocused = false
                    } else {
                        editingAddress = ""
                    }
                } label: {
                    Image(systemName: editingAddress.isEmpty ? "xmark" : "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    tab.reloadOrStop()
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(SealTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(addressFocused ? SealTheme.accent.opacity(0.8) : SealTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            if !addressFocused {
                addressFocused = true
            }
        }
    }

    @ViewBuilder
    private var siteIndicator: some View {
        if tab.address.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(SealTheme.accent)
                Text("S")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(width: 24, height: 24)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            ToolbarButton(symbol: "chevron.left", enabled: tab.canGoBack, action: tab.goBack)
            ToolbarButton(symbol: "chevron.right", enabled: tab.canGoForward, action: tab.goForward)

            Spacer(minLength: 20)

            ToolbarButton(symbol: "house", action: tab.home)

            Spacer(minLength: 20)

            Menu {
                Button {
                    browser.newTab()
                } label: {
                    Label("New Tab", systemImage: "plus")
                }

                Button {
                    tab.reloadOrStop()
                } label: {
                    Label(tab.isLoading ? "Stop Loading" : "Reload", systemImage: tab.isLoading ? "xmark" : "arrow.clockwise")
                }

                if !tab.address.isEmpty {
                    Button {
                        UIPasteboard.general.string = tab.address
                    } label: {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .frame(width: 44, height: 34)
                    .contentShape(Rectangle())
            }

            Spacer(minLength: 20)

            Button {
                tab.capturePreview()
                showingTabs = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1.4)
                        .frame(width: 24, height: 22)
                    Text("\(browser.tabs.count)")
                        .font(.system(size: browser.tabs.count > 9 ? 8 : 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs")
        }
        .padding(.horizontal, 2)
    }
}

private struct ToolbarButton: View {
    let symbol: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(enabled ? Color.white.opacity(0.78) : Color.white.opacity(0.20))
                .frame(width: 44, height: 34)
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
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                SealTheme.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(browser.tabs) { tab in
                            TabPreviewCard(
                                tab: tab,
                                isSelected: browser.selectedTabID == tab.id,
                                onSelect: {
                                    browser.selectTab(tab.id)
                                    isPresented = false
                                },
                                onClose: {
                                    browser.closeTab(tab.id)
                                },
                                onCloseOthers: {
                                    browser.closeOtherTabs(keeping: tab.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SealTheme.background.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(browser.tabs.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SealTheme.textSecondary)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        browser.newTab()
                        isPresented = false
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .tint(SealTheme.accent)

                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .tint(SealTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            browser.captureTabPreviews()
        }
    }
}

private struct TabPreviewCard: View {
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(height: 184)
                .clipped()

            HStack(spacing: 8) {
                SiteBadge(text: tab.address.isEmpty ? "S" : String(tab.displayHost.prefix(1)).uppercased())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(tab.address.isEmpty ? "Seal" : tab.displayHost)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(SealTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(SealTheme.surface)
        }
        .background(SealTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? SealTheme.accent : SealTheme.border, lineWidth: isSelected ? 1.6 : 1)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.black.opacity(0.58))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label("Open Tab", systemImage: "arrow.up.forward")
            }

            Button {
                onCloseOthers()
            } label: {
                Label("Close Other Tabs", systemImage: "rectangle.on.rectangle.slash")
            }

            Button(role: .destructive) {
                onClose()
            } label: {
                Label("Close Tab", systemImage: "xmark")
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = tab.previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        } else {
            ZStack {
                SealTheme.surfaceRaised

                VStack(spacing: 10) {
                    SiteBadge(text: tab.address.isEmpty ? "S" : String(tab.displayHost.prefix(1)).uppercased(), large: true)
                    Text(tab.address.isEmpty ? "New Tab" : tab.displayHost)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SealTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct SiteBadge: View {
    let text: String
    var large = false

    var body: some View {
        Text(text)
            .font(.system(size: large ? 20 : 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: large ? 46 : 24, height: large ? 46 : 24)
            .background(SealTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: large ? 13 : 7, style: .continuous))
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
