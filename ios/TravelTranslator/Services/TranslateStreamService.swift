import Foundation

/// 文本流式翻译的事件。
enum TranslateStreamEvent {
    case status(String)
    case delta(String)
    case final(TranslateStreamFinal)
    case error(String)
}

struct TranslateStreamFinal: Decodable {
    let translatedText: String
    let culturalNote: String?
    let engine: String

    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case culturalNote = "cultural_note"
        case engine
    }
}

/// 调后端 `/api/v1/translate/stream`，SSE token 级流式输出。
enum TranslateStreamService {
    private struct Body: Encodable {
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

    static func stream(
        sourceText: String,
        sourceLanguage: String,
        targetLanguage: String,
        polish: Bool,
        context: String? = nil
    ) -> AsyncThrowingStream<TranslateStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = APIConfig.baseURL.appendingPathComponent("/api/v1/translate/stream")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body = Body(
                        sourceText: sourceText,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        context: context,
                        polish: polish
                    )
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = 60

                    for try await sse in SSEClient.stream(request: request) {
                        if let event = Self.parse(sse) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parse(_ sse: SSEEvent) -> TranslateStreamEvent? {
        guard let data = sse.data.data(using: .utf8) else { return nil }
        switch sse.event {
        case "status":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["message"] as? String { return .status(msg) }
        case "delta":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = dict["text"] as? String { return .delta(text) }
        case "final":
            if let payload = try? JSONDecoder().decode(TranslateStreamFinal.self, from: data) {
                return .final(payload)
            }
        case "error":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["message"] as? String { return .error(msg) }
        default:
            break
        }
        return nil
    }
}
