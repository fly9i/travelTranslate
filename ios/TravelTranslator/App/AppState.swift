import Foundation

/// 全局应用状态。
@MainActor
final class AppState: ObservableObject {
    @Published var destination: Destination = Destinations.all[0]

    /// 根据定位结果设置默认目的地。没匹配到或权限被拒则保留当前值。
    func bootstrapFromLocation() async {
        guard let code = await LocationService.shared.currentCountryCode() else { return }
        if let matched = Destinations.byCountryCode(code) {
            destination = matched
        }
    }
}
