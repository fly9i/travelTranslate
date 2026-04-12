import Foundation

/// 场景短语服务。
final class PhraseService {
    static let shared = PhraseService()

    func fetchPackage(language: String, category: String? = nil) async throws -> PhrasePackage {
        var items: [URLQueryItem] = []
        if let category = category {
            items.append(URLQueryItem(name: "category", value: category))
        }
        return try await APIClient.shared.get(
            "/api/v1/phrases/packages/\(language)",
            query: items
        )
    }
}
