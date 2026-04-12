import Foundation

/// API 配置：baseURL 优先从 Info.plist 读取，缺省值用于模拟器开发。
enum APIConfig {
    static var baseURL: URL {
        let fromInfo = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let raw = fromInfo ?? ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8000"
        return URL(string: raw) ?? URL(string: "http://localhost:8000")!
    }
}
