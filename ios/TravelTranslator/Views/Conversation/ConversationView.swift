import SwiftUI

/// 实时对话页（简化版：文字输入 + 切换说话人）。
struct ConversationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = viewModel.error {
                Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal)
            }

            Divider()
            VStack(spacing: 8) {
                HStack {
                    TextField(
                        viewModel.speaker == "user" ? "我说中文…" : "对方说日文…",
                        text: $viewModel.input
                    )
                    .textFieldStyle(.roundedBorder)
                    Button("发送") {
                        Task { await viewModel.send() }
                    }
                    .disabled(viewModel.input.isEmpty || viewModel.loading)
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    viewModel.switchSpeaker()
                } label: {
                    Label(
                        viewModel.speaker == "user" ? "切换到对方说话" : "切换回我说话",
                        systemImage: "arrow.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("实时对话 🇨🇳 ↔ \(appState.destination.flag)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start(
                destination: appState.destination.name,
                source: "zh",
                target: appState.destination.language
            )
        }
    }
}

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var input: String = ""
    @Published var speaker: String = "user"
    @Published var loading = false
    @Published var error: String?

    private var conversationId: String?

    func start(destination: String, source: String, target: String) async {
        guard conversationId == nil else { return }
        do {
            let conv = try await ConversationService.shared.create(
                destination: destination,
                source: source,
                target: target
            )
            conversationId = conv.id
        } catch {
            self.error = error.localizedDescription
        }
    }

    func switchSpeaker() {
        speaker = (speaker == "user") ? "counterpart" : "user"
    }

    func send() async {
        guard let cid = conversationId, !input.isEmpty else { return }
        loading = true
        error = nil
        do {
            let msg = try await ConversationService.shared.send(
                conversationId: cid,
                speaker: speaker,
                text: input
            )
            messages.append(msg)
            input = ""
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
