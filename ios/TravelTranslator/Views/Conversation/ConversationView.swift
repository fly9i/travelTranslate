import SwiftUI

/// 实时对话页：文字 + 按住说话 + 朗读译文。
struct ConversationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationViewModel()
    @StateObject private var recognizer = SpeechRecognitionService.shared

    @State private var holdingToRecord = false
    @State private var cancelRecord = false

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

            if let error = viewModel.error ?? recognizer.errorMessage {
                Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal)
            }

            Divider()
            VStack(spacing: 8) {
                HStack {
                    TextField(
                        viewModel.speaker == "user"
                            ? "我说\(appState.userLocale.flag)…"
                            : "对方说\(appState.destination.flag)…",
                        text: $viewModel.input
                    )
                    .textFieldStyle(.roundedBorder)
                    .disabled(recognizer.isRecording)

                    Button("发送") {
                        Task {
                            await viewModel.send(
                                destination: appState.destination,
                                userLocale: appState.userLocale,
                                polish: appState.culturalPolish
                            )
                        }
                    }
                    .disabled(viewModel.input.isEmpty || viewModel.loading)
                    .buttonStyle(.borderedProminent)
                }

                Toggle("文化润色", isOn: $appState.culturalPolish)
                    .font(.footnote)

                // 按住说话按钮
                holdToTalkButton
                    .frame(maxWidth: .infinity)

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
        .navigationTitle("对话 \(appState.userLocale.flag) ↔ \(appState.destination.flag)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.start(
                destination: appState.destination.name,
                source: appState.userLocale.language,
                target: appState.destination.language
            )
            _ = await recognizer.requestAuthorization()
        }
        .overlay(alignment: .center) {
            if holdingToRecord {
                recordingOverlay
            }
        }
    }

    private var holdToTalkButton: some View {
        let label = recognizer.isRecording
            ? (cancelRecord ? "松开取消" : "松开发送")
            : "按住 说话"
        return Text(label)
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(recognizer.isRecording
                ? (cancelRecord ? Color.red.opacity(0.8) : Color.accentColor)
                : Color(.systemGray5))
            .foregroundStyle(recognizer.isRecording ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !holdingToRecord {
                            holdingToRecord = true
                            cancelRecord = false
                            startRecording()
                        }
                        // 向上滑超过 60 点视为取消
                        cancelRecord = value.translation.height < -60
                    }
                    .onEnded { _ in
                        let wasCancelled = cancelRecord
                        holdingToRecord = false
                        cancelRecord = false
                        finishRecording(cancelled: wasCancelled)
                    }
            )
    }

    private var recordingOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: cancelRecord ? "xmark.circle.fill" : "waveform")
                .font(.system(size: 56))
                .foregroundStyle(.white)
            Text(cancelRecord ? "松开手指取消" : "正在聆听…")
                .foregroundStyle(.white)
            if !recognizer.partialText.isEmpty {
                Text(recognizer.partialText)
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.footnote)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 220, height: 220)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func startRecording() {
        // user 说话 → 用户母语识别；counterpart 说话 → 目标语言识别
        let lang = viewModel.speaker == "user"
            ? appState.userLocale.voiceLanguage
            : appState.destination.voiceLanguage
        do {
            try recognizer.start(languageCode: lang)
        } catch {
            viewModel.error = error.localizedDescription
            holdingToRecord = false
        }
    }

    private func finishRecording(cancelled: Bool) {
        if cancelled {
            recognizer.cancel()
            return
        }
        let text = recognizer.stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.input = text
        Task {
            await viewModel.send(
                destination: appState.destination,
                userLocale: appState.userLocale,
                polish: appState.culturalPolish
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

    func send(destination: Destination, userLocale: UserLocale, polish: Bool) async {
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
            // 自动朗读译文：user 说话用目标语言念、counterpart 说话用用户母语念
            let voice = speaker == "user" ? destination.voiceLanguage : userLocale.voiceLanguage
            SpeechService.shared.speak(msg.translatedText, languageCode: voice)
            _ = polish // 对话接口的 polish 走 ConversationService，本版先保留开关，待后端对话接口升级
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
