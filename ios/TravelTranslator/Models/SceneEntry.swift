import Foundation

/// 场景入口。
struct SceneEntry: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let icon: String
    let label: String
}

/// 内置场景。
enum Scenes {
    static let all: [SceneEntry] = [
        SceneEntry(category: "restaurant", icon: "🍜", label: "餐厅"),
        SceneEntry(category: "transport", icon: "🚃", label: "交通"),
        SceneEntry(category: "hotel", icon: "🏨", label: "酒店"),
        SceneEntry(category: "shopping", icon: "🛍️", label: "购物"),
        SceneEntry(category: "emergency", icon: "🚨", label: "急救"),
        SceneEntry(category: "direction", icon: "🗺️", label: "问路"),
    ]
}
