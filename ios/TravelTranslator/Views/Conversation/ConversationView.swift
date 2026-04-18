import SwiftUI

/// 实时对话页：文字 + 按住说话 + 朗读译文。
struct ConversationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationViewModel()
    @StateObject private var recognizer = SpeechRecognitionService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var holdingToRecord = false
    @State private var cancelRecord = false

    var body: some View {
        ZStack {
            Theme.BG.base.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                conversationStream

                if let error = viewModel.error ?? recognizer.errorMessage {
                    Text(error)
                        .foregroundStyle(Theme.Semantic.danger)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                inputDock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }

            if holdingToRecord {
                recordingOverlay
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.start(
                destination: appState.destination.name,
                source: appState.userLocale.language,
                target: appState.destination.language
            )
            _ = await recognizer.requestAuthorization()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.FG.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Text(appState.userLocale.flag).font(.system(size: 20))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.FG.tertiary)
                Text(appState.destination.flag).font(.system(size: 20))
                Text("实时对话")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.FG.primary)
                    .padding(.leading, 4)
            }

            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var conversationStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubbleView(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input dock

    private var inputDock: some View {
        VStack(spacing: 10) {
            // 说话者切换
            HStack(spacing: 8) {
                speakerChip(
                    text: "\(appState.userLocale.flag) 我说",
                    active: viewModel.speaker == "user"
                ) {
                    viewModel.speaker = "user"
                }
                speakerChip(
                    text: "\(appState.destination.flag) 对方说",
                    active: viewModel.speaker == "counterpart"
                ) {
                    viewModel.speaker = "counterpart"
                }
            }

            // 按住说话主按钮
            holdToTalkButton

            Text("上滑取消 · 或直接输入文字")
                .font(.system(size: 11))
                .foregroundStyle(Theme.FG.tertiary)

            // 文字输入兜底
            HStack(spacing: 8) {
                TextField(
                    viewModel.speaker == "user"
                        ? "我说 \(appState.userLocale.flag)…"
                        : "对方说 \(appState.destination.flag)…",
                    text: $viewModel.input
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.BG.sunken)
                )
                .disabled(recognizer.isRecording)

                Button {
                    Task {
                        await viewModel.send(
                            destination: appState.destination,
                            userLocale: appState.userLocale,
                            polish: appState.culturalPolish
                        )
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.Accent.gradient))
                        .shadow(color: Theme.Accent.glow, radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.input.isEmpty || viewModel.loading)
                .opacity(viewModel.input.isEmpty ? 0.4 : 1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 40, x: 0, y: 12)
    }

    private func speakerChip(text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Theme.Accent.deep : Theme.FG.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active ? Theme.Accent.soft : Theme.FG.primary.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }

    private var holdToTalkButton: some View {
        let recording = recognizer.isRecording
        let title = recording
            ? (cancelRecord ? "松开取消" : "正在聆听… 松开翻译")
            : "按住 说话"
        return HStack(spacing: 10) {
            Image(systemName: "mic.fill")
            Text(title)
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(recording ? .white : Theme.FG.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(buttonFillStyle(recording: recording, cancel: cancelRecord))
        )
        .shadow(color: recording ? Theme.Accent.glow : .clear, radius: 20, x: 0, y: 8)
        .scaleEffect(recording ? 0.98 : 1)
        .animation(.easeOut(duration: 0.12), value: recording)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !holdingToRecord {
                        holdingToRecord = true
                        cancelRecord = false
                        startRecording()
                    }
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.75))
        )
    }

    private func buttonFillStyle(recording: Bool, cancel: Bool) -> AnyShapeStyle {
        if recording {
            return cancel
                ? AnyShapeStyle(Theme.Semantic.danger)
                : AnyShapeStyle(Theme.Accent.gradient)
        }
        return AnyShapeStyle(Theme.FG.primary.opacity(0.05))
    }

    private func startRecording() {
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
            let voice = speaker == "user" ? destination.voiceLanguage : userLocale.voiceLanguage
            SpeechService.shared.speak(msg.translatedText, languageCode: voice)
            _ = polish
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
