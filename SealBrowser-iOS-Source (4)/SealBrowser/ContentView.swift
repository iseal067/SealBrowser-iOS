import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var browser = BrowserStore()
    @State private var showingTabs = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.035, blue: 0.075)
                .ignoresSafeArea()

            if let tab = browser.selectedTab {
                BrowserPage(tab: tab, browser: browser, showingTabs: $showingTabs)
                    .id(tab.id)
            }
        }
        .sheet(isPresented: $showingTabs) {
            TabSwitcher(browser: browser, isPresented: $showingTabs)
                .presentationDetents([.medium, .large])
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
        VStack(spacing: 0) {
            topBar

            ZStack(alignment: .top) {
                WebViewContainer(tab: tab)
                    .background(Color(red: 0.012, green: 0.035, blue: 0.07))

                if tab.isLoading {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color(red: 0.05, green: 0.47, blue: 1.0), Color(red: 0.40, green: 0.52, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * tab.progress), height: 2)
                            .shadow(color: .blue.opacity(0.8), radius: 5)
                    }
                    .frame(height: 2)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
        }
        .background(Color(red: 0.01, green: 0.035, blue: 0.075))
        .onAppear {
            editingAddress = tab.address
        }
        .onChange(of: tab.address) { newValue in
            if !addressFocused {
                editingAddress = newValue
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.03, green: 0.34, blue: 0.95), Color(red: 0.0, green: 0.71, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.45), radius: 10)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(35))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Seal Browser")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(tab.displayHost)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color(red: 0.47, green: 0.68, blue: 0.88))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Button {
                browser.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color(red: 0.04, green: 0.17, blue: 0.34).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.blue.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.018, green: 0.065, blue: 0.14), Color(red: 0.018, green: 0.045, blue: 0.10)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.blue.opacity(0.22)).frame(height: 1)
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            addressBar
            navigationRow
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [Color(red: 0.015, green: 0.07, blue: 0.16).opacity(0.93), Color(red: 0.01, green: 0.035, blue: 0.085).opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color(red: 0.08, green: 0.45, blue: 0.95).opacity(0.25)).frame(height: 1)
        }
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.address.isEmpty ? "sparkles" : "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tab.address.isEmpty ? Color.cyan : Color(red: 0.40, green: 0.76, blue: 1.0))

            TextField("Search or enter a website", text: $editingAddress)
                .focused($addressFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .tint(Color.cyan)
                .onSubmit {
                    tab.open(editingAddress)
                    addressFocused = false
                }

            if addressFocused && !editingAddress.isEmpty {
                Button {
                    editingAddress = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 0.42, green: 0.60, blue: 0.78))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    tab.reloadOrStop()
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.62, green: 0.82, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.13, blue: 0.26), Color(red: 0.025, green: 0.085, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(addressFocused ? Color.cyan.opacity(0.9) : Color(red: 0.09, green: 0.40, blue: 0.76).opacity(0.7), lineWidth: addressFocused ? 1.4 : 1)
        )
        .shadow(color: addressFocused ? Color.blue.opacity(0.28) : Color.black.opacity(0.25), radius: 12, y: 5)
    }

    private var navigationRow: some View {
        HStack {
            BottomButton(symbol: "chevron.left", enabled: tab.canGoBack, action: tab.goBack)
            Spacer()
            BottomButton(symbol: "chevron.right", enabled: tab.canGoForward, action: tab.goForward)
            Spacer()
            BottomButton(symbol: "house.fill", action: tab.home)
            Spacer()
            BottomButton(symbol: "plus", action: { browser.newTab() })
            Spacer()

            Button {
                showingTabs = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(red: 0.62, green: 0.83, blue: 1.0), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    Text("\(browser.tabs.count)")
                        .font(.system(size: browser.tabs.count > 9 ? 8 : 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tabs")
        }
        .padding(.horizontal, 3)
    }
}

private struct BottomButton: View {
    let symbol: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Color(red: 0.70, green: 0.86, blue: 1.0) : Color(red: 0.25, green: 0.36, blue: 0.50))
                .frame(width: 42, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct TabSwitcher: View {
    @ObservedObject var browser: BrowserStore
    @Binding var isPresented: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.015, green: 0.055, blue: 0.13), Color(red: 0.01, green: 0.025, blue: 0.065)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(browser.tabs) { tab in
                            TabCard(
                                tab: tab,
                                isSelected: browser.selectedTabID == tab.id,
                                onSelect: {
                                    browser.selectTab(tab.id)
                                    isPresented = false
                                },
                                onClose: {
                                    browser.closeTab(tab.id)
                                }
                            )
                        }
                    }
                    .padding(14)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.015, green: 0.055, blue: 0.13), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(browser.tabs.count) open")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.49, green: 0.70, blue: 0.90))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        browser.newTab()
                        isPresented = false
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                    .tint(Color.cyan)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    browser.newTab()
                    isPresented = false
                } label: {
                    Label("New Tab", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.03, green: 0.38, blue: 1.0), Color(red: 0.0, green: 0.66, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TabCard: View {
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.18, blue: 0.38), Color(red: 0.025, green: 0.08, blue: 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: tab.address.isEmpty ? "sparkles" : "globe.americas.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color(red: 0.35, green: 0.72, blue: 1.0))
                    Text(tab.displayHost)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.64, green: 0.80, blue: 0.96))
                        .lineLimit(1)
                }
            }
            .frame(height: 112)

            VStack(alignment: .leading, spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(tab.address.isEmpty ? "Seal Browser" : tab.displayHost)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(red: 0.42, green: 0.59, blue: 0.76))
                    .lineLimit(1)
            }
            .padding(11)
        }
        .background(Color(red: 0.025, green: 0.07, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.cyan.opacity(0.95) : Color.blue.opacity(0.28), lineWidth: isSelected ? 1.7 : 1)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .shadow(color: isSelected ? Color.blue.opacity(0.22) : Color.black.opacity(0.22), radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onSelect)
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let tab: BrowserTab

    func makeUIView(context: Context) -> WKWebView {
        tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
