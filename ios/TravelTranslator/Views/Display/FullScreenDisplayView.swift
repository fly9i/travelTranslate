import SwiftUI

/// 全屏展示模式：大字译文递给对方看。珊瑚径向底 + 大字 + 原文小胶囊。
struct FullScreenDisplayView: View {
    let source: String
    let target: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 柔光径向底
            Color.white.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Accent.soft, .white],
                center: .init(x: 0.3, y: 0.3),
                startRadius: 20,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("请对方看")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.FG.tertiary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.FG.tertiary)
                    Spacer()
                }

                Text(target)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.FG.primary)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.leading)

                if !source.isEmpty {
                    Text(source)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.FG.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.FG.primary.opacity(0.04))
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 80)

            // 关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.FG.primary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle().fill(Theme.FG.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 56)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}
