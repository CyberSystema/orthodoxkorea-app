// ContentView.swift — Main app screen (WebView + bottom bar + language sheet)

import SwiftUI
import Foundation
#if os(iOS) || os(Android)
import SkipWeb
#endif

struct ContentView: View {

    #if os(iOS) || os(Android)

    @State var webState = WebViewState()
    @State var navigator = WebViewNavigator()
    @State var showLanguageSheet = false
    @State var scrapedTranslations: [TranslationInfo] = []
    @State var currentPageLanguage: String = ""
    @State var isOffline = false
    @State var pageSetupGeneration = 0

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL

    @State var configuration = WebEngineConfiguration(
        javaScriptEnabled: true,
        allowsBackForwardNavigationGestures: true,
        allowsPullToRefresh: true,
        allowsInlineMediaPlayback: true
    )

    #endif

    #if os(iOS) || os(Android)
    var barActions: BottomBarActions {
        BottomBarActions(
            canGoBack: webState.canGoBack,
            canGoForward: webState.canGoForward,
            onHome: { @MainActor in navigator.load(url: homeURL) },
            onBack: { @MainActor in navigator.goBack() },
            onRefresh: { @MainActor in navigator.reload() },
            onForward: { @MainActor in navigator.goForward() },
            onLanguage: { @MainActor in
                showLanguageSheet = true
            }
        )
    }
    #endif

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        iOSBody
        #else
        androidBody
        #endif
    }

    // MARK: - iOS Layout

    #if os(iOS)
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

    #if os(iOS) || os(Android)
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
        .onAppear {
            NotificationRouteBridge.shared.setHandler { url in
                showLanguageSheet = false
                isOffline = false
                if webState.url?.absoluteString != url.absoluteString {
                    navigator.load(url: url)
                }
            }
        }
        .onDisappear {
            NotificationRouteBridge.shared.clearHandler()
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
            pageSetupGeneration += 1
            let generation = pageSetupGeneration
            await doPageSetup()
            try? await Task.sleep(for: .milliseconds(800))
            guard generation == pageSetupGeneration, !webState.isLoading else { return }
            await doPageSetup()
            try? await Task.sleep(for: .milliseconds(700))
            guard generation == pageSetupGeneration, !webState.isLoading else { return }
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
            logger.error("page setup failed")
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

    #endif
}
