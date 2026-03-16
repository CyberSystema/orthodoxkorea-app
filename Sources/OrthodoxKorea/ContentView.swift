// ContentView.swift — Main app screen (WebView + bottom bar + language sheet)

import SwiftUI
import SkipWeb
import Foundation

struct ContentView: View {

    @State var webState = WebViewState()
    @State var navigator = WebViewNavigator()
    @State var showLanguageSheet = false
    @State var scrapedTranslations: [TranslationInfo] = []
    @State var currentPageLanguage: String = ""
    @State var isOffline = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL

    @State var configuration = WebEngineConfiguration(
        javaScriptEnabled: true,
        allowsBackForwardNavigationGestures: true,
        allowsPullToRefresh: true,
        allowsInlineMediaPlayback: true
    )

    var barActions: BottomBarActions {
        BottomBarActions(
            canGoBack: webState.canGoBack,
            canGoForward: webState.canGoForward,
            onHome: { @MainActor in navigator.load(url: homeURL) },
            onBack: { @MainActor in navigator.goBack() },
            onRefresh: { @MainActor in navigator.reload() },
            onForward: { @MainActor in navigator.goForward() },
            onLanguage: { @MainActor in
                Task { @MainActor in
                    await doPageSetup()
                    showLanguageSheet = true
                }
            }
        )
    }

    // MARK: - Body

    var body: some View {
        #if !os(Android)
        iOSBody
        #else
        androidBody
        #endif
    }

    // MARK: - iOS Layout

    #if !os(Android)
    @ViewBuilder
    var iOSBody: some View {
        if #available(iOS 26.0, *) {
            ZStack(alignment: .bottom) {
                webContent
                    .edgesIgnoringSafeArea(.bottom)
                IOSGlassBottomBar(actions: barActions)
            }
            .edgesIgnoringSafeArea(.top)
            .sheet(isPresented: $showLanguageSheet) { languageSheet }
        } else {
            VStack(spacing: 0) {
                webContent
                IOSFallbackBottomBar(actions: barActions)
            }
            .edgesIgnoringSafeArea(.top)
            .sheet(isPresented: $showLanguageSheet) { languageSheet }
        }
    }
    #endif

    // MARK: - Android Layout

    #if os(Android)
    var androidBody: some View {
        VStack(spacing: 0) {
            webContent
            AndroidBottomBar(actions: barActions)
        }
        .edgesIgnoringSafeArea(.top)
        .sheet(isPresented: $showLanguageSheet) { languageSheet }
    }
    #endif

    // MARK: - Web Content

    var webContent: some View {
        VStack(spacing: 0) {
            ProgressView(value: webState.isLoading ? (webState.estimatedProgress ?? 0) : 0)
                .progressViewStyle(.linear)
                .tint(adaptiveBrandColor(for: colorScheme))
                .opacity(webState.isLoading ? 1 : 0)
                .frame(height: 4)

            ZStack {
                WebView(
                    configuration: configuration,
                    navigator: navigator,
                    url: homeURL,
                    state: $webState,
                    shouldOverrideUrlLoading: { url in
                        if isAllowedURL(url) { return false }
                        openURL(url)
                        return true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isOffline {
                    OfflineView(onRetry: { @MainActor in
                        isOffline = false
                        if let url = webState.url {
                            navigator.load(url: url)
                        } else {
                            navigator.load(url: homeURL)
                        }
                    })
                }
            }
        }
        .onChange(of: webState.isLoading) { _, isLoading in
            if isLoading {
                isOffline = false
            } else {
                runPageSetup()
                if let error = webState.error {
                    let desc = "\(error)".lowercased()
                    if !desc.contains("cancel") {
                        isOffline = true
                    }
                }
            }
        }
    }

    // MARK: - Page Setup

    /// Runs pageSetupJS twice: immediately, then after 800ms for late-loading DOM widgets.
    func runPageSetup() {
        Task { @MainActor in
            await doPageSetup()
            try? await Task.sleep(for: .milliseconds(800))
            guard !webState.isLoading else { return }
            await doPageSetup()
        }
    }

    func doPageSetup() async {
        do {
            let result = try await navigator.evaluateJavaScript(pageSetupJS)
            let parsed = parsePageSetupResult(from: result)
            currentPageLanguage = parsed.currentLanguage
            scrapedTranslations = parsed.translations
        } catch {
            // Keep previous data rather than showing wrong fallback
        }
    }

    // MARK: - Language Sheet

    var languageSheet: some View {
        LanguageSheet(
            currentURL: webState.url,
            currentLanguage: currentPageLanguage,
            translations: scrapedTranslations,
            onSelect: { code, translatedURL in
                let destination = translatedURL ?? languageURL(for: code)
                if let currentURL = webState.url,
                   destination.absoluteString == currentURL.absoluteString {
                    showLanguageSheet = false
                    return
                }
                navigator.load(url: destination)
                showLanguageSheet = false
            },
            onDismiss: { showLanguageSheet = false }
        )
    }
}
