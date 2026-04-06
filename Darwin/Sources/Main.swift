// Main.swift — iOS app entry point, push notifications, and RSS feed checker

import SwiftUI
import WebKit
import OrthodoxKorea
import OneSignalFramework
import UserNotifications

private typealias AppRootView = OrthodoxKoreaRootView
private typealias AppDelegate = OrthodoxKoreaAppDelegate

// MARK: - App Entry Point

@main struct AppMain: App {

    @AppDelegateAdaptor(AppMainDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                AppDelegate.shared.onResume()
                Task { await PostChecker.checkForNewPosts() }
            case .inactive:
                AppDelegate.shared.onPause()
            case .background:
                AppDelegate.shared.onStop()
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Platform Type Aliases

#if canImport(UIKit)
typealias AppDelegateAdaptor = UIApplicationDelegateAdaptor
typealias AppMainDelegateBase = UIApplicationDelegate
typealias AppType = UIApplication
#elseif canImport(AppKit)
typealias AppDelegateAdaptor = NSApplicationDelegateAdaptor
typealias AppMainDelegateBase = NSApplicationDelegate
typealias AppType = NSApplication
#endif

// MARK: - App Delegate

@MainActor final class AppMainDelegate: NSObject, AppMainDelegateBase {

    let application = AppType.shared

    #if canImport(UIKit)

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppDelegate.shared.onInit()
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Allow notifications to display while the app is in the foreground
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Clear stale web content once on first launch after install.
        if !UserDefaults.standard.bool(forKey: "hasClearedInitialWebData") {
            let dataStore = WKWebsiteDataStore.default()
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date.distantPast
            ) {
                UserDefaults.standard.set(true, forKey: "hasClearedInitialWebData")
            }
        }

        // Initialize OneSignal (App ID stored in Info.plist)
        guard let oneSignalAppId = Bundle.main.object(forInfoDictionaryKey: "ONESIGNAL_APP_ID") as? String else {
            fatalError("ONESIGNAL_APP_ID not found in Info.plist")
        }
        OneSignal.initialize(oneSignalAppId, withLaunchOptions: launchOptions)
        OneSignal.Notifications.addClickListener(PushClickListener())

        // Request notification permission
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)

        // Initial RSS feed check (onChange doesn't fire for the first .active phase)
        Task { await PostChecker.checkForNewPosts() }

        AppDelegate.shared.onLaunch()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AppDelegate.shared.onDestroy()
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AppDelegate.shared.onLowMemory()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: NSNotification.Name("didRegisterForRemoteNotificationsWithDeviceToken"), object: application, userInfo: ["deviceToken": deviceToken])
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        NotificationCenter.default.post(name: NSNotification.Name("didFailToRegisterForRemoteNotificationsWithError"), object: application, userInfo: ["error": error])
    }

    #elseif canImport(AppKit)
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppDelegate.shared.onInit()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared.onLaunch()
    }

    func applicationWillTerminate(_ application: Notification) {
        AppDelegate.shared.onDestroy()
    }
    #endif
}

// MARK: - Push Click Listener

/// Records when a push notification is tapped to avoid duplicate RSS notifications.
private final class PushClickListener: NSObject, OSNotificationClickListener {
    func onClick(event: OSNotificationClickEvent) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastPushTime")
        NotificationRouteBridge.shared.route(urlString: event.result.url)
    }
}

// MARK: - Foreground Notification Delegate

/// Shows notification banners even when the app is in the foreground.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        OneSignal.Notifications.didReceiveNotificationResponse(response)

        if let urlString = response.notification.request.content.userInfo[notificationURLKey] as? String {
            NotificationRouteBridge.shared.route(urlString: urlString)
        }

        completionHandler()
    }
}

// MARK: - RSS Feed Checker

/// Backup notification system: checks RSS feeds on every app launch to detect
/// new posts in case OneSignal push delivery fails.
enum PostChecker {

    private static let languageCodes = ["en", "ko", "el", "ru", "uk"]

    private static var preferredLanguage: String {
        for language in Locale.preferredLanguages {
            let code = String(language.prefix(2)).lowercased()
            if languageCodes.contains(code) { return code }
        }
        return "en"
    }

    @discardableResult
    static func checkForNewPosts() async -> Bool {
        var newPostTitle: String?
        var newPostURL: URL?

        let preferred = preferredLanguage
        let orderedCodes = [preferred] + languageCodes.filter { $0 != preferred }

        for code in orderedCodes {
            guard let url = URL(string: "https://orthodoxkorea.org/\(code)/feed/") else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let post = RSSParser().parseLatestPost(from: data) else { continue }

                let key = "lastSeenGuid_\(code)"
                let lastSeenGuid = UserDefaults.standard.string(forKey: key)

                if lastSeenGuid == nil {
                    // First run: seed the GUID without notifying
                    UserDefaults.standard.set(post.guid, forKey: key)
                } else if post.guid != lastSeenGuid {
                    UserDefaults.standard.set(post.guid, forKey: key)
                    if newPostTitle == nil {
                        newPostTitle = post.title
                        newPostURL = post.url
                    }
                }
            } catch {
                // Network error — skip this language
            }
        }

        if let title = newPostTitle {
            // Only send local notification if no OneSignal push was received in the last 6 hours
            let lastPush = UserDefaults.standard.double(forKey: "lastPushTime")
            let hoursSinceLastPush = (Date().timeIntervalSince1970 - lastPush) / 3600
            if lastPush == 0 || hoursSinceLastPush > 2 {
                await sendLocalNotification(title: title, url: newPostURL)
            }
        }

        return true
    }

    private static func sendLocalNotification(title: String, url: URL?) async {
        let content = UNMutableNotificationContent()
        content.title = "Orthodox Korea"
        content.body = title
        content.sound = .default
        if let url {
            content.userInfo[notificationURLKey] = url.absoluteString
        }

        let request = UNNotificationRequest(
            identifier: "newpost-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification delivery failed
        }
    }
}

// MARK: - RSS Parser

private struct RSSPost {
    let title: String
    let guid: String
    let url: URL?
}

private final class RSSParser: NSObject, XMLParserDelegate {

    private var currentElement = ""
    private var currentTitle = ""
    private var currentGuid = ""
    private var currentLink = ""
    private var insideItem = false
    private var latestPost: RSSPost?

    func parseLatestPost(from data: Data) -> RSSPost? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return latestPost
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentGuid = ""
            currentLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "guid": currentGuid += string
        case "link": currentLink += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" && insideItem {
            if latestPost == nil {
                let trimmedGuid = currentGuid.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
                latestPost = RSSPost(
                    title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    guid: trimmedGuid,
                    url: normalizedNotificationURL(from: trimmedLink) ?? normalizedNotificationURL(from: trimmedGuid)
                )
            }
            insideItem = false
            parser.abortParsing()
        }
        currentElement = ""
    }
}
