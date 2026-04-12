import Foundation

/// 全局应用状态。
@MainActor
final class AppState: ObservableObject {
    @Published var destination: Destination = Destinations.all[0]

    func switchDestination() {
        let list = Destinations.all
        guard let idx = list.firstIndex(where: { $0.code == destination.code }) else { return }
        destination = list[(idx + 1) % list.count]
    }
}
