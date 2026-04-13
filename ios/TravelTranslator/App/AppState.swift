import Foundation

/// 全局应用状态。
@MainActor
final class AppState: ObservableObject {
    @Published var destination: Destination {
        didSet { persist() }
    }
    @Published var userLocale: UserLocale {
        didSet { persist() }
    }
    /// 是否启用文化润色（LLM 地道化 + 文化提醒）。
    @Published var culturalPolish: Bool {
        didSet { UserDefaults.standard.set(culturalPolish, forKey: Self.polishKey) }
    }

    private static let destKey = "app.destination.code"
    private static let userKey = "app.userLocale.code"
    private static let polishKey = "app.culturalPolish"

    init() {
        let defaults = UserDefaults.standard
        if let code = defaults.string(forKey: Self.destKey),
           let saved = Destinations.byCountryCode(code) {
            self.destination = saved
        } else {
            self.destination = Destinations.all[0]
        }
        if let code = defaults.string(forKey: Self.userKey),
           let saved = UserLocales.all.first(where: { $0.code == code }) {
            self.userLocale = saved
        } else {
            self.userLocale = UserLocales.fromSystemLocale()
        }
        self.culturalPolish = defaults.bool(forKey: Self.polishKey)
    }

    private func persist() {
        UserDefaults.standard.set(destination.code, forKey: Self.destKey)
        UserDefaults.standard.set(userLocale.code, forKey: Self.userKey)
    }

    /// 根据定位结果设置默认目的地。没匹配到或权限被拒则保留当前值。
    func bootstrapFromLocation() async {
        guard let code = await LocationService.shared.currentCountryCode() else { return }
        if let matched = Destinations.byCountryCode(code) {
            destination = matched
        }
    }
}
