import SwiftUI

/// 根视图：三 Tab 浮动玻璃 bar —— 场景 / 主页(大) / 历史。
/// 设置通过首页齿轮按钮进入。
struct RootView: View {
    @State private var tab: FloatingTabBar.Tab = .camera
    /// 已在首页再次点击中间拍摄按钮时递增 —— HomeView 通过 onChange 唤起相机。
    @State private var cameraCaptureTick: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .scenes:
                    NavigationStack { SceneListView() }
                case .camera:
                    NavigationStack { HomeView(captureTick: cameraCaptureTick) }
                case .history:
                    NavigationStack { HistoryView() }
                }
            }
            .transition(.opacity)

            FloatingTabBar(selection: $tab, onCameraReTap: {
                cameraCaptureTick &+= 1
            })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
