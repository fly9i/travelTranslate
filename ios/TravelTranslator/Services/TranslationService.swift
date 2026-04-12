import Foundation

/// 翻译结果。
struct TranslationResult: Codable {
    let translatedText: String
    let transliteration: String?
    let confidence: Double
    let engine: String
    let cached: Bool

    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case transliteration
        case confidence
        case engine
        case cached
    }
}

/// 翻译请求。
struct TranslateRequest: Encodable {
    let sourceText: String
    let sourceLanguage: String
    let targetLanguage: String
    let context: String?

    enum CodingKeys: String, CodingKey {
        case sourceText = "source_text"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case context
    }
}

/// 翻译服务：调后端 /api/v1/translate。
final class TranslationService {
    static let shared = TranslationService()

    func translate(
        text: String,
        from source: String = "zh",
        to target: String,
        context: String? = nil
    ) async throws -> TranslationResult {
        let body = TranslateRequest(
            sourceText: text,
            sourceLanguage: source,
            targetLanguage: target,
            context: context
        )
        return try await APIClient.shared.post("/api/v1/translate", body: body)
    }
}
