# Contributing to Orthodox Korea

Thank you for your interest in contributing to the Orthodox Korea app.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Install prerequisites (see [README.md](README.md#prerequisites))
4. Create a feature branch from `main`

## Development Guidelines

### Code Style

- **Swift**: PascalCase for types, camelCase for properties/methods, 4-space indentation
- **No debug output**: Remove all `print()` statements and `console.log` before submitting
- **No hardcoded secrets**: Use platform config files (Info.plist / gradle.properties)

### Localization

All user-facing strings must be localized:

- Use `Text("Key")` with string literals (SwiftUI auto-resolves via `LocalizedStringKey`)
- For dynamic strings passed as parameters, use `LocalizedStringKey` type instead of `String`
- Add translations for all supported languages (en, ko, el, ru, uk) in `Sources/OrthodoxKorea/Resources/Localizable.xcstrings`

### Platform Compatibility

This is a Skip Fuse project. Keep in mind:

- Shared code in `Sources/OrthodoxKorea/` runs on both iOS and Android
- Use `#if os(Android)` / `#if !os(Android)` for platform-specific code
- `@State` properties must be `internal` (not `private`) for Skip compatibility
- Not all SwiftUI modifiers are supported on Android via Skip — test on both platforms

### Security

- All external URLs must pass through `isAllowedURL()` in AppConstants.swift
- Only HTTPS URLs are permitted
- New domains must be added to the `allowedHosts` allowlist

## Submitting Changes

1. Ensure your code builds with **0 errors and 0 warnings**
2. Test on both iOS Simulator and Android Emulator
3. Open a Pull Request against `main`
4. Fill out the PR template completely

## Reporting Issues

Use the [issue templates](https://github.com/niccoloGreat/orthodoxkorea-app/issues/new/choose) to report bugs or request features.
