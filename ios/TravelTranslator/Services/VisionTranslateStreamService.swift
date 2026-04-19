import Foundation
import UIKit

/// 流式视觉翻译接口产生的事件（与后端 SSE 协议一一对应）。
enum VisionTranslateStreamEvent {
    case status(String)
    case delta(String)
    case final(VisionTranslateFinal)
    case error(String)
}

/// 最终 JSON 结构。ocr_indices 对应前端 OCR 块下标。
struct VisionTranslateFinal: Decodable {
    let sceneType: String
    let summary: String
    let engine: String
    let items: [VisionTranslateFinalItem]

    enum CodingKeys: String, CodingKey {
        case sceneType = "scene_type"
        case summary
        case engine
        case items
    }
}

struct VisionTranslateFinalItem: Decodable, Identifiable {
    let id = UUID()
    let ocrIndices: [Int]
    let sourceText: String
    let translatedText: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case ocrIndices = "ocr_indices"
        case sourceText = "source_text"
        case translatedText = "translated_text"
        case note
    }
}

/// 调后端 `/api/v1/vision/translate/stream`，返回事件流。
enum VisionTranslateStreamService {
    /// bbox 使用归一化 0–1、左上原点坐标系 —— 便于 LLM 按人类阅读顺序理解。
    /// iOS 发送前会把 Vision 原生的左下原点换算过来。
    struct OCRBlockPayload: Encodable {
        let index: Int
        let text: String
        let bbox: BBox

        struct BBox: Encodable {
            let x: Double
            let y: Double
            let w: Double
            let h: Double
        }
    }

    static func stream(
        image: UIImage,
        blocks: [OCRBlockPayload],
        sourceLanguage: String,
        targetLanguage: String,
        destination: String?
    ) -> AsyncThrowingStream<VisionTranslateStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                        throw APIError.http(0, "图片编码失败")
                    }
                    let url = APIConfig.baseURL.appendingPathComponent(
                        "/api/v1/vision/translate/stream"
                    )
                    let boundary = "Boundary-\(UUID().uuidString)"
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue(
                        "multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type"
                    )
                    request.httpBody = Self.makeMultipartBody(
                        boundary: boundary,
                        jpeg: jpeg,
                        blocks: blocks,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        destination: destination
                    )
                    request.timeoutInterval = 120

                    for try await sse in SSEClient.stream(request: request) {
                        let event = Self.parse(event: sse)
                        if let event {
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

    private static func parse(event sse: SSEEvent) -> VisionTranslateStreamEvent? {
        guard let data = sse.data.data(using: .utf8) else { return nil }
        switch sse.event {
        case "status":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["message"] as? String {
                return .status(msg)
            }
        case "delta":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = dict["text"] as? String {
                return .delta(text)
            }
        case "final":
            if let payload = try? JSONDecoder().decode(VisionTranslateFinal.self, from: data) {
                return .final(payload)
            }
        case "error":
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["message"] as? String {
                return .error(msg)
            }
        default:
            break
        }
        return nil
    }

    private static func makeMultipartBody(
        boundary: String,
        jpeg: Data,
        blocks: [OCRBlockPayload],
        sourceLanguage: String,
        targetLanguage: String,
        destination: String?
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!
            )
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }

        // image
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\(crlf)"
                .data(using: .utf8)!
        )
        body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(jpeg)
        body.append(crlf.data(using: .utf8)!)

        // ocr_blocks JSON
        let blocksJson: String = {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(blocks),
               let s = String(data: data, encoding: .utf8) {
                return s
            }
            return "[]"
        }()
        appendField(name: "ocr_blocks", value: blocksJson)
        appendField(name: "source_language", value: sourceLanguage)
        appendField(name: "target_language", value: targetLanguage)
        if let destination, !destination.isEmpty {
            appendField(name: "destination", value: destination)
        }

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }
}
