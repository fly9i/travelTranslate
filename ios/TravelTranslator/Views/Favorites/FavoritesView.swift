import SwiftUI

/// 收藏页（本地存储版本，简化实现）。
struct FavoritesView: View {
    @StateObject private var store = FavoritesStore()

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "还没有收藏",
                    systemImage: "star",
                    description: Text("在短语卡片上点击收藏，这里会显示你的常用短语。")
                )
            } else {
                List {
                    ForEach(store.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.sourceText).foregroundStyle(.secondary)
                            Text(item.targetText).font(.headline)
                        }
                    }
                    .onDelete { indexSet in store.remove(at: indexSet) }
                }
            }
        }
        .navigationTitle("收藏")
    }
}

/// 本地收藏条目。
struct FavoriteItem: Identifiable, Codable {
    let id: UUID
    let sourceText: String
    let targetText: String
    let targetLanguage: String
}

/// 简单的本地收藏存储（UserDefaults）。
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [FavoriteItem] = []

    private let key = "favorites.v1"

    init() {
        load()
    }

    func add(_ item: FavoriteItem) {
        items.insert(item, at: 0)
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
