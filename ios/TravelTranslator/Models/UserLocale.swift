import Foundation

/// 用户母语/国家：决定翻译的 source 语言、译文朗读语种、场景解说的输出语种。
struct UserLocale: Identifiable, Hashable, Codable {
    let code: String          // ISO 国家码
    let language: String      // BCP-47 语言子标签（zh/en/ja…）
    let voiceLanguage: String // 完整 BCP-47
    let flag: String
    let name: String          // 用户母语里自己国家的名字

    var id: String { code }
}

enum UserLocales {
    static let all: [UserLocale] = [
        UserLocale(code: "CN", language: "zh", voiceLanguage: "zh-CN", flag: "🇨🇳", name: "中国（简体）"),
        UserLocale(code: "TW", language: "zh", voiceLanguage: "zh-TW", flag: "🇨🇳", name: "台湾（繁体）"),
        UserLocale(code: "HK", language: "zh", voiceLanguage: "zh-HK", flag: "🇭🇰", name: "香港（繁体）"),
        UserLocale(code: "US", language: "en", voiceLanguage: "en-US", flag: "🇺🇸", name: "United States"),
        UserLocale(code: "GB", language: "en", voiceLanguage: "en-GB", flag: "🇬🇧", name: "United Kingdom"),
        UserLocale(code: "JP", language: "ja", voiceLanguage: "ja-JP", flag: "🇯🇵", name: "日本"),
        UserLocale(code: "KR", language: "ko", voiceLanguage: "ko-KR", flag: "🇰🇷", name: "한국"),
        UserLocale(code: "FR", language: "fr", voiceLanguage: "fr-FR", flag: "🇫🇷", name: "France"),
        UserLocale(code: "DE", language: "de", voiceLanguage: "de-DE", flag: "🇩🇪", name: "Deutschland"),
        UserLocale(code: "ES", language: "es", voiceLanguage: "es-ES", flag: "🇪🇸", name: "España"),
        UserLocale(code: "IT", language: "it", voiceLanguage: "it-IT", flag: "🇮🇹", name: "Italia"),
        UserLocale(code: "RU", language: "ru", voiceLanguage: "ru-RU", flag: "🇷🇺", name: "Россия"),
    ]

    static let `default` = all[0]

    /// 根据系统 Locale 推导默认用户地区。
    static func fromSystemLocale() -> UserLocale {
        let locale = Locale.current
        let region = locale.region?.identifier ?? "CN"
        if let match = all.first(where: { $0.code == region }) {
            return match
        }
        let lang = locale.language.languageCode?.identifier ?? "zh"
        if let byLang = all.first(where: { $0.language == lang }) {
            return byLang
        }
        return `default`
    }
}
