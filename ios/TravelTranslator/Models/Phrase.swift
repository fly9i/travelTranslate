import Foundation

/// 场景短语。
struct Phrase: Identifiable, Codable, Hashable {
    let id: String
    let sceneCategory: String
    let subcategory: String?
    let sourceText: String
    let targetText: String
    let sourceLanguage: String
    let targetLanguage: String
    let transliteration: String?
    let isCustom: Bool
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sceneCategory = "scene_category"
        case subcategory
        case sourceText = "source_text"
        case targetText = "target_text"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case transliteration
        case isCustom = "is_custom"
        case priority
    }
}

struct PhrasePackage: Codable {
    let language: String
    let total: Int
    let phrases: [Phrase]
}
