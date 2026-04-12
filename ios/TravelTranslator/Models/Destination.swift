import Foundation

/// 目的地。
struct Destination: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let language: String
    let flag: String
    let name: String
}

/// 内置目的地列表。
enum Destinations {
    static let all: [Destination] = [
        Destination(code: "JP", language: "ja", flag: "🇯🇵", name: "东京"),
        Destination(code: "KR", language: "ko", flag: "🇰🇷", name: "首尔"),
        Destination(code: "US", language: "en", flag: "🇺🇸", name: "美国"),
        Destination(code: "TH", language: "th", flag: "🇹🇭", name: "曼谷"),
        Destination(code: "FR", language: "fr", flag: "🇫🇷", name: "巴黎"),
        Destination(code: "DE", language: "de", flag: "🇩🇪", name: "柏林"),
    ]
}
