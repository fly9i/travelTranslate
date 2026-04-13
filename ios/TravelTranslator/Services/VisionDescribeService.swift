import Foundation

struct VisionItem: Codable, Identifiable {
    var id: String { (original ?? "") + name }
    let name: String
    let original: String?
    let description: String?
    let tags: [String]
    let recommendation: String?
}

struct VisionDescribeResult: Codable {
    let sceneType: String
    let summary: String
    let items: [VisionItem]
    let warnings: [String]
    let engine: String

    enum CodingKeys: String, CodingKey {
        case sceneType = "scene_type"
        case summary
        case items
        case warnings
        case engine
    }
}

private struct VisionDescribeRequest: Encodable {
    let ocrTexts: [String]
    let sourceLanguage: String
    let userLanguage: String
    let destination: String?
    let hint: String?

    enum CodingKeys: String, CodingKey {
        case ocrTexts = "ocr_texts"
        case sourceLanguage = "source_language"
        case userLanguage = "user_language"
        case destination
        case hint
    }
}

/// 场景理解服务：调后端 /api/v1/vision/describe。
final class VisionDescribeService {
    static let shared = VisionDescribeService()

    func describe(
        ocrTexts: [String],
        sourceLanguage: String,
        userLanguage: String,
        destination: String?,
        hint: String? = nil
    ) async throws -> VisionDescribeResult {
        let body = VisionDescribeRequest(
            ocrTexts: ocrTexts,
            sourceLanguage: sourceLanguage,
            userLanguage: userLanguage,
            destination: destination,
            hint: hint
        )
        return try await APIClient.shared.post("/api/v1/vision/describe", body: body)
    }
}
