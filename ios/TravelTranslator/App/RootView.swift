import SwiftUI

/// 根视图：三 Tab 浮动玻璃 bar —— 场景 / 主页(大) / 历史。
/// 设置通过首页齿轮按钮进入。
struct RootView: View {
    @State private var tab: FloatingTabBar.Tab = .camera

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .scenes:
                    NavigationStack { SceneListView() }
                case .camera:
                    NavigationStack { HomeView() }
                case .history:
                    NavigationStack { HistoryView() }
                }
            }
            .transition(.opacity)

            FloatingTabBar(selection: $tab)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
