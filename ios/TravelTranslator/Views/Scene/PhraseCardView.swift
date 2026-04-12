import SwiftUI

/// 短语卡片。
struct PhraseCardView: View {
    let phrase: Phrase
    @State private var showDisplay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(phrase.sourceText).foregroundStyle(.secondary)
            Text(phrase.targetText).font(.title3).bold()
            if let tl = phrase.transliteration {
                Text(tl).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    let code = PhraseCardView.localeCode(for: phrase.targetLanguage)
                    SpeechService.shared.speak(phrase.targetText, languageCode: code)
                } label: {
                    Label("朗读", systemImage: "speaker.wave.2.fill")
                }
                Spacer()
                Button {
                    showDisplay = true
                } label: {
                    Label("展示", systemImage: "tv")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showDisplay) {
            FullScreenDisplayView(source: phrase.sourceText, target: phrase.targetText)
        }
    }

    /// 简单映射：语言代码 → 本地化标识符。
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
