import SwiftUI

/// 短语卡片：小号原文灰字 + 大号译文 + 罗马音 + 朗读/展示胶囊按钮。
struct PhraseCardView: View {
    let phrase: Phrase
    @State private var showDisplay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(phrase.sourceText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.FG.secondary)

            Text(phrase.targetText)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.FG.primary)
                .lineSpacing(2)

            if let tl = phrase.transliteration, !tl.isEmpty {
                Text(tl)
                    .font(.system(size: 13).italic())
                    .foregroundStyle(Theme.FG.tertiary)
            }

            HStack(spacing: 8) {
                Button {
                    let code = PhraseCardView.localeCode(for: phrase.targetLanguage)
                    SpeechService.shared.speak(phrase.targetText, languageCode: code)
                } label: {
                    Label("朗读", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Accent.deep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.Accent.soft))
                }
                .buttonStyle(.plain)

                Button {
                    showDisplay = true
                } label: {
                    Label("展示", systemImage: "tv")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.FG.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().strokeBorder(
                                Theme.FG.primary.opacity(0.1),
                                lineWidth: 0.5
                            )
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    // 收藏占位
                } label: {
                    Image(systemName: "star")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.FG.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.BG.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
        )
        .designShadow(Theme.Shadow.soft)
        .sheet(isPresented: $showDisplay) {
            FullScreenDisplayView(source: phrase.sourceText, target: phrase.targetText)
        }
    }

    static func localeCode(for language: String) -> String {
        switch language {
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "en": return "en-US"
        case "th": return "th-TH"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        default: return "en-US"
        }
    }
}
