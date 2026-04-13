import Foundation

/// 翻译结果。
struct TranslationResult: Codable {
    let translatedText: String
    let transliteration: String?
    let confidence: Double
    let engine: String
    let cached: Bool
    let culturalNote: String?

    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case transliteration
        case confidence
        case engine
        case cached
        case culturalNote = "cultural_note"
    }
}

/// 翻译请求。
struct TranslateRequest: Encodable {
    let sourceText: String
    let sourceLanguage: String
    let targetLanguage: String
    let context: String?
    let polish: Bool

    enum CodingKeys: String, CodingKey {
        case sourceText = "source_text"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case context
        case polish
    }
}

/// 翻译服务：调后端 /api/v1/translate。
final class TranslationService {
    static let shared = TranslationService()

    func translate(
        text: String,
        from source: String = "zh",
        to target: String,
        context: String? = nil,
        polish: Bool = false
    ) async throws -> TranslationResult {
        let body = TranslateRequest(
            sourceText: text,
            sourceLanguage: source,
            targetLanguage: target,
            context: context,
            polish: polish
        )
        return try await APIClient.shared.post("/api/v1/translate", body: body)
    }
}
