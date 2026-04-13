import Foundation

/// 目的地。
struct Destination: Identifiable, Hashable {
    let code: String          // ISO 3166-1 alpha-2 国家码
    let language: String      // BCP-47 语言子标签（传给后端翻译接口）
    let voiceLanguage: String // 完整 BCP-47 code（传给 AVSpeechSynthesisVoice）
    let flag: String
    let name: String          // 中文名
    let localName: String     // 目的地本地名称

    var id: String { code }
}

/// 内置目的地列表。覆盖常见出境游目的地。
enum Destinations {
    static let all: [Destination] = [
        // 东亚
        Destination(code: "JP", language: "ja", voiceLanguage: "ja-JP", flag: "🇯🇵", name: "日本", localName: "日本"),
        Destination(code: "KR", language: "ko", voiceLanguage: "ko-KR", flag: "🇰🇷", name: "韩国", localName: "한국"),
        Destination(code: "HK", language: "zh", voiceLanguage: "zh-HK", flag: "🇭🇰", name: "香港", localName: "香港"),
        Destination(code: "TW", language: "zh", voiceLanguage: "zh-TW", flag: "🇨🇳", name: "台湾", localName: "臺灣"),
        // 东南亚
        Destination(code: "TH", language: "th", voiceLanguage: "th-TH", flag: "🇹🇭", name: "泰国", localName: "ประเทศไทย"),
        Destination(code: "VN", language: "vi", voiceLanguage: "vi-VN", flag: "🇻🇳", name: "越南", localName: "Việt Nam"),
        Destination(code: "SG", language: "en", voiceLanguage: "en-SG", flag: "🇸🇬", name: "新加坡", localName: "Singapore"),
        Destination(code: "MY", language: "ms", voiceLanguage: "ms-MY", flag: "🇲🇾", name: "马来西亚", localName: "Malaysia"),
        Destination(code: "ID", language: "id", voiceLanguage: "id-ID", flag: "🇮🇩", name: "印度尼西亚", localName: "Indonesia"),
        Destination(code: "PH", language: "en", voiceLanguage: "en-PH", flag: "🇵🇭", name: "菲律宾", localName: "Pilipinas"),
        // 北美
        Destination(code: "US", language: "en", voiceLanguage: "en-US", flag: "🇺🇸", name: "美国", localName: "United States"),
        Destination(code: "CA", language: "en", voiceLanguage: "en-CA", flag: "🇨🇦", name: "加拿大", localName: "Canada"),
        // 欧洲
        Destination(code: "GB", language: "en", voiceLanguage: "en-GB", flag: "🇬🇧", name: "英国", localName: "United Kingdom"),
        Destination(code: "FR", language: "fr", voiceLanguage: "fr-FR", flag: "🇫🇷", name: "法国", localName: "France"),
        Destination(code: "DE", language: "de", voiceLanguage: "de-DE", flag: "🇩🇪", name: "德国", localName: "Deutschland"),
        Destination(code: "IT", language: "it", voiceLanguage: "it-IT", flag: "🇮🇹", name: "意大利", localName: "Italia"),
        Destination(code: "ES", language: "es", voiceLanguage: "es-ES", flag: "🇪🇸", name: "西班牙", localName: "España"),
        Destination(code: "PT", language: "pt", voiceLanguage: "pt-PT", flag: "🇵🇹", name: "葡萄牙", localName: "Portugal"),
        Destination(code: "NL", language: "nl", voiceLanguage: "nl-NL", flag: "🇳🇱", name: "荷兰", localName: "Nederland"),
        Destination(code: "CH", language: "de", voiceLanguage: "de-CH", flag: "🇨🇭", name: "瑞士", localName: "Schweiz"),
        Destination(code: "RU", language: "ru", voiceLanguage: "ru-RU", flag: "🇷🇺", name: "俄罗斯", localName: "Россия"),
        Destination(code: "TR", language: "tr", voiceLanguage: "tr-TR", flag: "🇹🇷", name: "土耳其", localName: "Türkiye"),
        // 大洋洲
        Destination(code: "AU", language: "en", voiceLanguage: "en-AU", flag: "🇦🇺", name: "澳大利亚", localName: "Australia"),
        Destination(code: "NZ", language: "en", voiceLanguage: "en-NZ", flag: "🇳🇿", name: "新西兰", localName: "New Zealand"),
        // 中东
        Destination(code: "AE", language: "ar", voiceLanguage: "ar-AE", flag: "🇦🇪", name: "阿联酋", localName: "الإمارات"),
        Destination(code: "SA", language: "ar", voiceLanguage: "ar-SA", flag: "🇸🇦", name: "沙特阿拉伯", localName: "السعودية"),
    ]

    static func byCountryCode(_ code: String) -> Destination? {
        all.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}
