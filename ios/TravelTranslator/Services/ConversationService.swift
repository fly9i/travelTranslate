import Foundation

/// 对话服务。
final class ConversationService {
    static let shared = ConversationService()

    struct CreateBody: Encodable {
        let destination: String?
        let sourceLanguage: String
        let targetLanguage: String

        enum CodingKeys: String, CodingKey {
            case destination
            case sourceLanguage = "source_language"
            case targetLanguage = "target_language"
        }
    }

    struct SendBody: Encodable {
        let speaker: String
        let sourceText: String
        let inputType: String

        enum CodingKeys: String, CodingKey {
            case speaker
            case sourceText = "source_text"
            case inputType = "input_type"
        }
    }

    func create(destination: String?, source: String, target: String) async throws -> Conversation {
        try await APIClient.shared.post(
            "/api/v1/conversations",
            body: CreateBody(destination: destination, sourceLanguage: source, targetLanguage: target)
        )
    }

    func send(conversationId: String, speaker: String, text: String) async throws -> Message {
        try await APIClient.shared.post(
            "/api/v1/conversations/\(conversationId)/messages",
            body: SendBody(speaker: speaker, sourceText: text, inputType: "text")
        )
    }
}
