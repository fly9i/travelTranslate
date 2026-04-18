import SwiftUI

/// 对话气泡：我方（珊瑚橙渐变 · 右对齐）/ 对方（米白卡片 · 左对齐）。
struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        let isUser = message.speaker == "user"
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(isUser ? "我 · 中文" : "对方")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.FG.tertiary)
                .padding(.horizontal, 8)

            bubble(isUser: isUser)

            Button {
                SpeechService.shared.speak(message.translatedText, languageCode: "ja-JP")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: 9))
                    Text("朗读译文").font(.system(size: 11))
                }
                .foregroundStyle(Theme.FG.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func bubble(isUser: Bool) -> some View {
        let userShape = UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 20,
            bottomTrailingRadius: 4,
            topTrailingRadius: 20,
            style: .continuous
        )
        let counterShape = UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 4,
            bottomTrailingRadius: 20,
            topTrailingRadius: 20,
            style: .continuous
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(message.sourceText)
                .font(.system(size: 15))
            Divider()
                .background(
                    (isUser ? Color.white.opacity(0.25) : Theme.FG.primary.opacity(0.08))
                )
            Text(message.translatedText)
                .font(.system(size: 14))
                .foregroundStyle(isUser ? Color.white.opacity(0.85) : Theme.FG.secondary)
        }
        .foregroundStyle(isUser ? Color.white : Theme.FG.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 280, alignment: .leading)
        .background(
            Group {
                if isUser {
                    userShape.fill(Theme.Accent.gradient)
                } else {
                    counterShape.fill(Theme.BG.elevated)
                }
            }
        )
        .overlay(
            Group {
                if !isUser {
                    counterShape
                        .strokeBorder(Theme.FG.primary.opacity(0.05), lineWidth: 0.5)
                }
            }
        )
        .shadow(
            color: isUser ? Theme.Accent.glow : Color.black.opacity(0.06),
            radius: isUser ? 16 : 4,
            x: 0, y: isUser ? 6 : 1
        )
    }
}
