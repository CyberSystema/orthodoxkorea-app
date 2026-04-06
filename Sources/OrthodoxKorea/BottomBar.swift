// BottomBar.swift — Platform-specific bottom navigation bars
//
// Three variants:
//   1. IOSGlassBottomBar    — iOS 26+ with Liquid Glass
//   2. IOSFallbackBottomBar — iOS < 26 with .ultraThinMaterial
//   3. AndroidBottomBar     — Material-style with elevation

import SwiftUI

// MARK: - Shared Actions

struct BottomBarActions {
    var canGoBack: Bool
    var canGoForward: Bool
    var onHome: @MainActor @Sendable () -> Void
    var onBack: @MainActor @Sendable () -> Void
    var onRefresh: @MainActor @Sendable () -> Void
    var onForward: @MainActor @Sendable () -> Void
    var onLanguage: @MainActor @Sendable () -> Void
}

// MARK: - iOS Liquid Glass (iOS 26+)

#if !os(Android)

@available(iOS 26.0, *)
struct IOSGlassBottomBar: View {
    var actions: BottomBarActions

    var body: some View {
        GeometryReader { geo in
            let barHeight: CGFloat = geo.size.width < 390 ? 56 : (geo.size.width < 768 ? 60 : 66)
            let iconSize = barHeight * 0.38
            let labelSize = barHeight * 0.18

            HStack(spacing: 0) {
                glassBarButton(icon: "house.fill", label: "Home", iconSize: iconSize, labelSize: labelSize, action: actions.onHome)
                glassBarButton(icon: "chevron.left", label: "Back", iconSize: iconSize, labelSize: labelSize, disabled: !actions.canGoBack, action: actions.onBack)
                glassBarButton(icon: "arrow.clockwise", label: "Refresh", iconSize: iconSize, labelSize: labelSize, action: actions.onRefresh)
                glassBarButton(icon: "chevron.right", label: "Forward", iconSize: iconSize, labelSize: labelSize, disabled: !actions.canGoForward, action: actions.onForward)
                glassBarButton(icon: "globe", label: "Language", iconSize: iconSize, labelSize: labelSize, action: actions.onLanguage)
            }
            .padding(.horizontal, 6)
            .frame(width: geo.size.width - 24, height: barHeight)
            .glassEffect(.regular, in: .capsule)
            .frame(width: geo.size.width, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 78)
        .padding(.bottom, 4)
    }

    private func glassBarButton(icon: String, label: LocalizedStringKey, iconSize: CGFloat, labelSize: CGFloat, disabled: Bool = false, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                Text(label)
                    .font(.system(size: labelSize, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1.0)
    }
}

// MARK: - iOS Fallback (< iOS 26)

struct IOSFallbackBottomBar: View {
    var actions: BottomBarActions
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color { adaptiveBrandColor(for: colorScheme) }

    var body: some View {
        HStack(spacing: 0) {
            barButton(icon: "house.fill", label: "Home", action: actions.onHome)
            barButton(icon: "chevron.left", label: "Back", disabled: !actions.canGoBack, action: actions.onBack)
            barButton(icon: "arrow.clockwise", label: "Refresh", action: actions.onRefresh)
            barButton(icon: "chevron.right", label: "Forward", disabled: !actions.canGoForward, action: actions.onForward)
            barButton(icon: "globe", label: "Language", action: actions.onLanguage)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(.ultraThinMaterial)
    }

    private func barButton(icon: String, label: LocalizedStringKey, disabled: Bool = false, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(disabled ? Color.gray.opacity(0.4) : accentColor)
        }
        .disabled(disabled)
    }
}
#endif

// MARK: - Android

#if os(Android)
struct AndroidBottomBar: View {
    var actions: BottomBarActions
    @Environment(\.colorScheme) var colorScheme

    private var accentColor: Color { adaptiveBrandColor(for: colorScheme) }

    private var barBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color.white
    }

    private var barShadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 0) {
            barButton(icon: "house.fill", label: "Home", action: actions.onHome)
            barButton(icon: "chevron.left", label: "Back", disabled: !actions.canGoBack, action: actions.onBack)
            barButton(icon: "arrow.clockwise.circle", label: "Refresh", action: actions.onRefresh)
            barButton(icon: "chevron.right", label: "Forward", disabled: !actions.canGoForward, action: actions.onForward)
            // Globe emoji because SF Symbol "globe" has no Android mapping
            Button(action: actions.onLanguage) {
                VStack(spacing: 3) {
                    Text("🌐").font(.system(size: 24))
                    Text("Language").font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(accentColor)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(barBackground.shadow(color: barShadowColor, radius: 8, x: 0, y: -2))
    }

    private func barButton(icon: String, label: LocalizedStringKey, disabled: Bool = false, action: @escaping @MainActor @Sendable () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(disabled ? Color.gray.opacity(0.4) : accentColor)
        }
        .disabled(disabled)
    }
}
#endif
