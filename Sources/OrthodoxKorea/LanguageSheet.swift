// LanguageSheet.swift — Language selection modal

import SwiftUI

struct LanguageSheet: View {

    var currentURL: URL?
    var currentLanguage: String
    var translations: [TranslationInfo]
    var onSelect: (String, URL?) -> Void
    var onDismiss: () -> Void

    /// Shows only languages with available translations; falls back to all if scraping failed.
    var displayLanguages: [LanguageOption] {
        guard !translations.isEmpty else { return availableLanguages }
        let scrapedCodes = Set(translations.map { $0.code })
        return availableLanguages.filter { scrapedCodes.contains($0.id) }
    }

    func translationURL(for code: String) -> URL? {
        translations.first(where: { $0.code == code })?.url
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayLanguages) { language in
                    Button {
                        onSelect(language.id, translationURL(for: language.id))
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.nativeName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.primary)

                                Text(language.name)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }

                            Spacer()

                            if currentLanguage == language.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(brandColor)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Language")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
        .presentationDetents([.height(CGFloat(130 + displayLanguages.count * 70))])
    }
}
