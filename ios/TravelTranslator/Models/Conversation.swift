import Foundation

/// 对话。
struct Conversation: Codable, Identifiable {
    let id: String
    let destination: String?
    let sourceLanguage: String
    let targetLanguage: String
    let messageCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case destination
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case messageCount = "message_count"
    }
}

/// 对话消息。
struct Message: Codable, Identifiable {
    let id: String
    let conversationId: String
    let speaker: String
    let sourceText: String
    let translatedText: String
    let inputType: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case speaker
        case sourceText = "source_text"
        case translatedText = "translated_text"
        case inputType = "input_type"
    }
}
