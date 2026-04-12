import SwiftUI

/// 消息气泡。
struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        let isUser = message.speaker == "user"
        HStack {
            if !isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(isUser ? "🧑 你" : "👤 对方")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.sourceText)
                Text(message.translatedText)
                    .bold()
            }
            .padding(10)
            .background(isUser ? Color(.systemGray6) : Color.blue.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if isUser { Spacer() }
        }
    }
}
