// OfflineView.swift — Offline error overlay

import SwiftUI

struct OfflineView: View {

    var onRetry: @MainActor @Sendable () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            #if !os(Android)
            Image(systemName: "wifi.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondary)
            #else
            Image(systemName: "xmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondary)
            #endif

            Text("No Connection")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)

            Text("Check your internet connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.white)
                    .background(brandColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}
