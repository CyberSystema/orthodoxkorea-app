# Orthodox Korea

The official mobile app for the [Orthodox Metropolis of Korea](https://orthodoxkorea.org) (Ecumenical Patriarchate), built as a cross-platform application for **iOS** and **Android** using [Skip Fuse](https://skip.dev).

## Features

- **Full website experience** — Native WebView wrapping orthodoxkorea.org with smooth navigation
- **Dynamic language switcher** — Scrapes available translations from each page and lets users switch between Korean, English, Greek, Russian, Ukrainian, and more
- **Push notifications** — Powered by OneSignal with RSS-based backup notifications for new content
- **Offline detection** — Graceful offline screen with retry functionality
- **Animated splash screen** — Custom branded launch experience
- **Dark mode support** — Adapts to system appearance on both platforms
- **Localized UI** — Bottom bar and system text translated into Korean, Greek, Russian, and Ukrainian
- **Security hardened** — Domain allowlist, HTTPS enforcement, no hardcoded secrets

## Architecture

This is a [Skip Fuse](https://skip.dev) project: a single Swift codebase that runs natively on iOS and is transpiled to Kotlin for Android.

```
orthodoxkorea-app/
├── Sources/OrthodoxKorea/       # Shared cross-platform code (Swift)
│   ├── AppConstants.swift       # URLs, JS injection, security, language config
│   ├── ContentView.swift        # Main WebView + navigation + offline handling
│   ├── BottomBar.swift          # Platform-specific bottom navigation bars
│   ├── LanguageSheet.swift      # Language selection modal
│   ├── OfflineView.swift        # No-connection overlay
│   ├── OrthodoxKoreaApp.swift   # Root app entry with splash screen
│   ├── SplashScreenView.swift   # Animated launch screen
│   └── Resources/               # Assets, localization strings
├── Darwin/                      # iOS-specific entry point & config
│   ├── Sources/Main.swift       # iOS AppDelegate, OneSignal, notifications
│   ├── Info.plist               # iOS configuration
│   └── fastlane/                # iOS deployment automation
├── Android/                     # Android-specific entry point & config
│   ├── app/src/main/kotlin/Main.kt  # Android Application, OneSignal, notifications
│   ├── app/build.gradle.kts     # Android build configuration
│   └── fastlane/                # Android deployment automation
├── Package.swift                # Swift Package Manager manifest
└── Skip.env                     # Shared app metadata (version, bundle ID)
```

## Prerequisites

1. **Xcode** (latest version) — for iOS builds
2. **Skip** — install via Homebrew:
   ```bash
   brew install skiptools/skip/skip
   ```
   This also installs Kotlin, Gradle, and Android build tools.
3. **Android Studio** — for the Android emulator
4. Verify your setup:
   ```bash
   skip checkup
   ```

## Building & Running

### iOS

Open `Project.xcworkspace` in Xcode and run the **Orthodox Korea** target on a simulator or device.

### Android

1. Launch an Android emulator from Android Studio's Device Manager
2. Run the **Orthodox Korea** target from Xcode — the Skip build plugin automatically deploys to the running emulator

### Both Platforms Simultaneously

Running from Xcode with the **Orthodox Korea** target builds and launches on both iOS Simulator and a connected Android emulator at the same time.

## Configuration

### App Metadata

Shared app properties (version, bundle ID, etc.) are defined in `Skip.env`:

| Property | Value |
|----------|-------|
| Bundle ID | `org.orthodoxkorea.orthodoxkorea` |
| Version | `1.0.0` |
| Min iOS | 17.0 |

### Push Notifications

- **iOS**: OneSignal App ID is stored in `Darwin/Info.plist`
- **Android**: OneSignal App ID is stored in `Android/gradle.properties`
- Firebase config for Android is in `Android/app/google-services.json`

### Deployment

Fastlane is configured for both platforms:
- **iOS**: `Darwin/fastlane/` — App Store deployment
- **Android**: `Android/fastlane/` — Google Play deployment

## Localization

The app UI is localized into 5 languages:

| Language | Code |
|----------|------|
| English | `en` |
| Korean | `ko` |
| Greek | `el` |
| Russian | `ru` |
| Ukrainian | `uk` |

Translations are managed in `Sources/OrthodoxKorea/Resources/Localizable.xcstrings`.

## Security

- **Domain allowlist** — only orthodoxkorea.org and required embed domains (Google Maps, YouTube) are permitted
- **HTTPS enforced** — all non-HTTPS requests are blocked
- **No hardcoded secrets** — service keys are externalized to platform config files
- **ProGuard** enabled for Android release builds (minification + resource shrinking)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

Copyright 2025 Orthodox Metropolis of Korea (Ecumenical Patriarchate). All rights reserved.
