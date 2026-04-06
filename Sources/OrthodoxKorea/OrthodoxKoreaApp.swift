// OrthodoxKoreaApp.swift — Cross-platform root view and lifecycle delegate

import Foundation
import SwiftUI

struct AppLogger {
    let subsystem: String
    let category: String

    private func write(_ level: String, _ message: String) {
        print("[\(level)] \(subsystem).\(category): \(message)")
    }

    func info(_ message: String) {
        write("INFO", message)
    }

    func debug(_ message: String) {
        write("DEBUG", message)
    }

    func error(_ message: String) {
        write("ERROR", message)
    }
}

let logger = AppLogger(subsystem: "org.orthodoxkorea.orthodoxkorea", category: "OrthodoxKorea")

// MARK: - Root View

/* SKIP @bridge */public struct OrthodoxKoreaRootView : View {

    /* SKIP @bridge */public init() {
    }

    @State var splashOpacity: Double = 1.0

    public var body: some View {
        ZStack {
            ContentView()

            // iOS: splash stays in view tree at opacity 0 to prevent first-tap bug.
            // Android: removed from tree once faded (Skip may not support .allowsHitTesting).
            #if os(Android)
            if splashOpacity > 0 {
                SplashScreenView()
                    .opacity(splashOpacity)
            }
            #else
            SplashScreenView()
                .opacity(splashOpacity)
                .allowsHitTesting(splashOpacity > 0)
            #endif
        }
        .task {
            logger.info("Orthodox Korea app launched")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.easeInOut(duration: 1.0)) {
                splashOpacity = 0.0
            }
        }
    }
}

// MARK: - Lifecycle Delegate

/* SKIP @bridge */public final class OrthodoxKoreaAppDelegate : Sendable {

    /* SKIP @bridge */public static let shared = OrthodoxKoreaAppDelegate()

    private init() {
    }

    /* SKIP @bridge */public func onInit() {
        logger.debug("onInit")
    }

    /* SKIP @bridge */public func onLaunch() {
        logger.debug("onLaunch")
    }

    /* SKIP @bridge */public func onResume() {
        logger.debug("onResume")
    }

    /* SKIP @bridge */public func onPause() {
        logger.debug("onPause")
    }

    /* SKIP @bridge */public func onStop() {
        logger.debug("onStop")
    }

    /* SKIP @bridge */public func onDestroy() {
        logger.debug("onDestroy")
    }

    /* SKIP @bridge */public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
