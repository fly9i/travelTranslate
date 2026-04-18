import SwiftUI

/// 根视图：三 Tab 浮动玻璃 bar —— 场景 / 相机(大) / 历史。
/// 设置通过首页的齿轮按钮进入。
struct RootView: View {
    @State private var tab: FloatingTabBar.Tab = .camera

    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容层：按当前 tab 切换
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

            // 悬浮 TabBar（相机 tab 为沉浸式取景器时隐藏）
            if tab != .camera {
                FloatingTabBar(selection: $tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // 相机 tab 仍提供切换入口，但透明度更低，不抢镜头层
                FloatingTabBar(selection: $tab)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
