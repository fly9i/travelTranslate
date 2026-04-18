import SwiftUI

/// 底部浮动玻璃 TabBar —— 场景 / 相机(大圆按钮) / 历史。
struct FloatingTabBar: View {
    enum Tab: String, CaseIterable {
        case scenes, camera, history
    }

    @Binding var selection: Tab
    /// 已在首页(camera tab)时再次点击中间大按钮的回调 —— 用于直接唤起拍摄。
    var onCameraReTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.scenes, icon: "square.grid.2x2", label: "场景")
            cameraButton
            tabButton(.history, icon: "clock", label: "历史")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(height: 68)
        .background(
            Capsule(style: .continuous).fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.14), radius: 32, x: 0, y: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        let active = tab == selection
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: active ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? Theme.Accent.base : Theme.FG.tertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cameraButton: some View {
        Button {
            if selection == .camera {
                onCameraReTap()
            } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selection = .camera
                }
            }
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(Theme.Accent.gradient)
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Theme.Accent.glow, radius: 18, x: 0, y: 8)
                .offset(y: -4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
