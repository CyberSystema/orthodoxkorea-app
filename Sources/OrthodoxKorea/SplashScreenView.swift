// SplashScreenView.swift — Animated splash screen
//
// Animation sequence (~8s total):
//   Phase 1 (0–2s):   Logo fades in + scales from 0.6 → 1.0
//   Phase 2 (1.5–3.5s): Text fades in + slides up
//   Phase 3 (3–5.5s):  Golden glow ring pulses outward
//   Phase 4 (6.5–7.5s): Entire splash fades out (handled by parent)

import SwiftUI

struct SplashScreenView: View {

    @State var logoOpacity: Double = 0.0
    @State var logoScale: CGFloat = 0.6
    @State var textOpacity: Double = 0.0
    @State var textOffset: CGFloat = 20.0
    @State var glowOpacity: Double = 0.0
    @State var glowScale: CGFloat = 0.8

    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.04, blue: 0.04)
            : Color(red: 0.6, green: 0.15, blue: 0.15)
    }

    var glowColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.75, blue: 0.4)
            : Color(red: 1.0, green: 0.85, blue: 0.5)
    }

    var textColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.42, blue: 0.42)
            : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    // Glow ring: blur on iOS, concentric circles on Android
                    #if !os(Android)
                    Circle()
                        .fill(glowColor)
                        .frame(width: 220, height: 220)
                        .blur(radius: 45)
                        .opacity(glowOpacity * 0.3)
                        .scaleEffect(glowScale)
                    #else
                    Circle()
                        .fill(glowColor.opacity(0.05))
                        .frame(width: 260, height: 260)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                    Circle()
                        .fill(glowColor.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                    #endif

                    Image("splash_logo", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                }

                VStack(spacing: 8) {
                    Text("Orthodox Korea")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(textColor)
                        .minimumScaleFactor(0.7)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(textColor.opacity(0.4))
                        .frame(width: 50, height: 2)

                    Text("orthodoxkorea.org")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(textColor.opacity(0.7))
                        .minimumScaleFactor(0.7)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                Spacer()
                Spacer()
            }
        }
        .task {
            await runAnimationSequence()
        }
    }

    func runAnimationSequence() async {
        withAnimation(.easeOut(duration: 2.0)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        withAnimation(.easeOut(duration: 2.0)) {
            textOpacity = 1.0
            textOffset = 0.0
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        withAnimation(.easeInOut(duration: 2.5)) {
            glowOpacity = 1.0
            glowScale = 1.15
        }
    }
}
