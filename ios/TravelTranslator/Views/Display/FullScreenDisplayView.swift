import SwiftUI

/// 全屏展示模式：大字译文递给对方看。
struct FullScreenDisplayView: View {
    let source: String
    let target: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(target)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("(\(source))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button {
                    dismiss()
                } label: {
                    Label("关闭", systemImage: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
