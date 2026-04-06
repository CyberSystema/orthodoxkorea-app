// AppConstants.swift — Brand colors, languages, URL helpers, and security

import SwiftUI

// MARK: - Brand Colors

let brandColor = Color(red: 0.6, green: 0.15, blue: 0.15)

func adaptiveBrandColor(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0.9, green: 0.42, blue: 0.42) : brandColor
}

let baseURL = "https://orthodoxkorea.org"
public let notificationURLKey = "notification_url"

// MARK: - Supported Languages

let supportedLanguageCodes: Set<String> = ["en", "ko", "el", "ru", "uk"]

struct LanguageOption: Identifiable {
    let id: String
    let name: String
    let nativeName: String
    let flag: String
}

let availableLanguages: [LanguageOption] = [
    LanguageOption(id: "en", name: "English", nativeName: "English", flag: "🇬🇧"),
    LanguageOption(id: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
    LanguageOption(id: "el", name: "Greek", nativeName: "Ελληνικά", flag: "🇬🇷"),
    LanguageOption(id: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
    LanguageOption(id: "uk", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦"),
]

// MARK: - URL Helpers

/// Home URL based on the device's preferred language; defaults to English.
let homeURL: URL = {
    for language in Locale.preferredLanguages {
        let code = String(language.prefix(2)).lowercased()
        if supportedLanguageCodes.contains(code) {
            return URL(string: "\(baseURL)/\(code)")!
        }
    }
    return URL(string: "\(baseURL)/en")!
}()

func languageURL(for code: String) -> URL {
    URL(string: "\(baseURL)/\(code)")!
}

/* SKIP @bridge */public func normalizedNotificationURL(from urlString: String?) -> URL? {
    guard let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty,
          let url = URL(string: trimmed),
          isAllowedURL(url) else {
        return nil
    }

    return url
}

// MARK: - Notification Routing

/* SKIP @bridge */public final class NotificationRouteBridge : @unchecked Sendable {

    /* SKIP @bridge */public static let shared = NotificationRouteBridge()

    private let stateQueue = DispatchQueue(label: "org.orthodoxkorea.notification-route")
    private var handler: ((URL) -> Void)?
    private var pendingURL: URL?

    private init() {
    }

    /* SKIP @bridge */public func route(urlString: String?) {
        guard let url = normalizedNotificationURL(from: urlString) else { return }

        let activeHandler = stateQueue.sync { () -> ((URL) -> Void)? in
            if let handler {
                return handler
            }

            pendingURL = url
            return nil
        }

        if let activeHandler {
            DispatchQueue.main.async {
                activeHandler(url)
            }
        }
    }

    func setHandler(_ handler: @escaping (URL) -> Void) {
        let pendingURL = stateQueue.sync { () -> URL? in
            self.handler = handler
            let pendingURL = self.pendingURL
            self.pendingURL = nil
            return pendingURL
        }

        if let pendingURL {
            handler(pendingURL)
        }
    }

    func clearHandler() {
        stateQueue.sync {
            handler = nil
        }
    }
}

// MARK: - Translation Scraping (Polylang)

struct TranslationInfo: Identifiable {
    let id: String
    let code: String
    let url: URL
}

/// Combined JS that runs after every page load:
///  1. Injects safe-area CSS (pushes content below the notch)
///  2. Registers a passive touch listener (fixes WKWebView first-tap bug)
///  3. Scrapes Polylang translation links
///
/// Returns: `"el:::ko|url1||en|url2||el|url3"` (current lang before `:::`, translations after).
let pageSetupJS = """
(function() {
    if (!document.getElementById('skip-safe-area-style')) {
        var style = document.createElement('style');
        style.id = 'skip-safe-area-style';
        style.textContent = 'body { padding-top: env(safe-area-inset-top) !important; }';
        document.head.appendChild(style);
        var viewport = document.querySelector('meta[name=viewport]');
        if (viewport && !viewport.content.includes('viewport-fit')) {
            viewport.content += ', viewport-fit=cover';
        }
    }

    if (!document._skipTouchFixed) {
        document._skipTouchFixed = true;
        document.addEventListener('touchstart', function(){}, {passive: true});
    }
    void(document.body && document.body.offsetHeight);

    var valid = ['en','ko','el','ru','uk'];
    var seen = {};
    var results = [];

    function add(code, url) {
        if (valid.indexOf(code) !== -1 && !seen[code]) {
            seen[code] = true;
            results.push(code + '|' + url);
        }
    }

    var langItems = document.querySelectorAll('[class*="lang-item-"]');
    for (var i = 0; i < langItems.length; i++) {
        var classes = langItems[i].className;
        var match = classes.match(/lang-item-([a-z]{2})/);
        if (match) {
            var code = match[1];
            var link = langItems[i].querySelector('a[href]');
            if (link && link.href && link.href.indexOf('#pll_switcher') === -1) {
                add(code, link.href);
            }
        }
    }

    if (results.length === 0) {
        var hrefLinks = document.querySelectorAll('a[hreflang]');
        for (var h = 0; h < hrefLinks.length; h++) {
            add(hrefLinks[h].getAttribute('hreflang'), hrefLinks[h].href);
        }
    }

    var htmlLang = (document.documentElement.lang || '').substring(0, 2).toLowerCase();
    add(htmlLang, window.location.href);

    return htmlLang + ':::' + results.join('||');
})()
"""

struct PageSetupResult {
    let currentLanguage: String
    let translations: [TranslationInfo]
}

/// Parses the pipe-delimited string returned by `pageSetupJS`.
/// Handles evaluateJavaScript's JSON quoting by stripping surrounding quotes.
func parsePageSetupResult(from rawString: String?) -> PageSetupResult {
    guard var str = rawString, !str.isEmpty else {
        return PageSetupResult(currentLanguage: "", translations: [])
    }

    while str.count >= 2 && str.hasPrefix("\"") && str.hasSuffix("\"") {
        str = String(str.dropFirst().dropLast())
        str = str.replacingOccurrences(of: "\\\"", with: "\"")
        str = str.replacingOccurrences(of: "\\/", with: "/")
        str = str.replacingOccurrences(of: "\\\\", with: "\\")
    }

    guard !str.isEmpty else {
        return PageSetupResult(currentLanguage: "", translations: [])
    }

    var currentLanguage = ""
    var translationStr = str
    if let separatorRange = str.range(of: ":::") {
        currentLanguage = String(str[str.startIndex..<separatorRange.lowerBound])
        translationStr = String(str[separatorRange.upperBound...])
    }

    let translations: [TranslationInfo] = translationStr.components(separatedBy: "||").compactMap { entry in
        guard let pipeIndex = entry.firstIndex(of: "|") else { return nil }
        let code = String(entry[entry.startIndex..<pipeIndex])
        let urlStr = String(entry[entry.index(after: pipeIndex)...])
        guard !code.isEmpty, !urlStr.isEmpty, let url = URL(string: urlStr) else { return nil }
        return TranslationInfo(id: code, code: code, url: url)
    }

    return PageSetupResult(currentLanguage: currentLanguage, translations: translations)
}

// MARK: - Security

/// Domains allowed to load inside the WebView. External URLs open in the system browser.
/// Includes embed domains (Google Maps, YouTube) used by the website's WordPress content.
let allowedHosts: Set<String> = [
    "orthodoxkorea.org", "www.orthodoxkorea.org",
    // Google Maps embeds
    "maps.google.com", "www.google.com", "maps.googleapis.com",
    // YouTube embeds
    "www.youtube.com", "youtube.com", "www.youtube-nocookie.com",
]

/// Returns true if the URL uses HTTPS and belongs to an allowed host.
func isAllowedURL(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "https" else { return false }
    guard let host = url.host?.lowercased() else { return false }
    return allowedHosts.contains(host)
}
