import SwiftUI

/// 根视图：四个 Tab。
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("翻译", systemImage: "house") }

            NavigationStack { SceneListView() }
                .tabItem { Label("场景", systemImage: "square.grid.2x2") }

            NavigationStack { FavoritesView() }
                .tabItem { Label("收藏", systemImage: "star") }

            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
