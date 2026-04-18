import PhotosUI
import SwiftUI

/// 首页 —— 卡片式布局：大标题 + 语言对 + 首选"拍 everything"卡 + 对话/场景次级卡 + 即时翻译样例卡。
struct HomeView: View {
    /// 父视图(RootView)在已停留在本页时再次点击中间拍摄按钮会递增此值 —— 用于唤起相机。
    var captureTick: Int = 0

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var history = HistoryStore.shared

    @State private var showingDestinationPicker = false
    @State private var showingSettings = false
    @State private var showingCamera = false
    @State private var showingConversation = false
    @State private var showingTextPanel = false
    @State private var showingOCRDetail = false
    @State private var showingScenes = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.BG.base.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.top, 8)

                    LangPairPill(
                        fromFlag: appState.userLocale.flag,
                        toFlag: appState.destination.flag,
                        toName: appState.destination.name,
                        onTap: { showingDestinationPicker = true }
                    )

                    primaryCameraCard
                        .padding(.top, 4)

                    secondaryRow

                    SectionHeaderView(title: "即时翻译")
                        .padding(.top, 6)

                    quickTranslateCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 140)
            }

        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selection: $appState.destination)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showingTextPanel) {
            TextInputSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onImage: { image in
                    showingCamera = false
                    pendingImage = image
                    showingOCRDetail = true
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingConversation) {
            NavigationStack { ConversationView() }
        }
        .navigationDestination(isPresented: $showingOCRDetail) {
            if let img = pendingImage {
                CameraOCRView(initialImage: img)
            }
        }
        .navigationDestination(isPresented: $showingScenes) {
            SceneListView()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingImage = image
                    showingOCRDetail = true
                }
                pickerItem = nil
            }
        }
        .task {
            await appState.bootstrapFromLocation()
        }
        .onChange(of: captureTick) { _, _ in
            showingCamera = true
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今天在 \(appState.destination.flag)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.FG.primary)
                    .tracking(-0.5)
                Text("\(appState.destination.name) · \(appState.destination.localName)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.FG.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    iconButton(systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button {
                    showingSettings = true
                } label: {
                    iconButton(systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconButton(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.FG.secondary)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Theme.FG.primary.opacity(0.05)))
    }

    private var primaryCameraCard: some View {
        Button {
            showingCamera = true
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.Accent.gradient)

                // 右上角大相机水印
                Image(systemName: "camera.fill")
                    .font(.system(size: 160, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .rotationEffect(.degrees(-8))
                    .offset(x: 180, y: -30)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text("首选功能")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("拍 everything")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(-0.5)
                    Text("菜单、路牌、小票、门票 —— 对准就能读懂")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                        .frame(maxWidth: 240, alignment: .leading)

                    HStack(spacing: 6) {
                        Text("开始拍摄")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
                    .padding(.top, 12)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.Accent.glow, radius: 32, x: 0, y: 16)
        }
        .buttonStyle(.plain)
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            secondaryCard(
                icon: "mic.fill",
                chip: .sky,
                title: "对话翻译",
                subtitle: "按住说话"
            ) {
                showingConversation = true
            }
            secondaryCard(
                icon: "square.grid.2x2.fill",
                chip: .mint,
                title: "场景短语",
                subtitle: "\(Scenes.all.count) 个常用分类"
            ) {
                showingScenes = true
            }
        }
    }

    private func secondaryCard(
        icon: String,
        chip: Theme.Chip,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(chip.fg)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(chip.bg)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.FG.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.FG.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.BG.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
            )
            .designShadow(Theme.Shadow.soft)
        }
        .buttonStyle(.plain)
    }

    private var quickTranslateCard: some View {
        let latest = latestTextEntry
        let sourceLang = latest?.sourceLanguage ?? appState.userLocale.language
        let targetLang = latest?.targetLanguage ?? appState.destination.language
        let sourceText = latest?.sourceText ?? "附近有便宜的居酒屋推荐吗？"
        let translated = latest?.translatedText
        let targetLabel = Self.languageLabel(targetLang, destination: appState.destination)
        let sourceLabel = Self.languageLabel(sourceLang, userLocale: appState.userLocale)

        return Button {
            showingTextPanel = true
        } label: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.FG.tertiary)
                    Text(sourceText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.FG.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

                Divider().background(Theme.FG.primary.opacity(0.05))

                VStack(alignment: .leading, spacing: 10) {
                    Text(targetLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Accent.deep)
                    if let translated, !translated.isEmpty {
                        Text(translated)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.FG.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("点击输入想说的话 → 即时翻译")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.FG.secondary)
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("输入文字")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.Accent.base))

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.FG.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.Accent.soft)
            }
            .background(Theme.BG.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
            )
            .designShadow(Theme.Shadow.soft)
        }
        .buttonStyle(.plain)
    }

    private var latestTextEntry: HistoryTextEntry? {
        history.entries.first(where: { $0.kind == .text })?.text
    }

    private static func languageLabel(_ lang: String, destination: Destination) -> String {
        if lang == destination.language { return destination.localName }
        return languageDisplayName(lang)
    }

    private static func languageLabel(_ lang: String, userLocale: UserLocale) -> String {
        if lang == userLocale.language { return userLocale.name }
        return languageDisplayName(lang)
    }

    private static func languageDisplayName(_ lang: String) -> String {
        switch lang {
        case "zh": return "中文"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "en": return "English"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "es": return "Español"
        case "it": return "Italiano"
        case "pt": return "Português"
        case "ru": return "Русский"
        case "th": return "ภาษาไทย"
        case "vi": return "Tiếng Việt"
        case "ms": return "Bahasa Melayu"
        case "id": return "Bahasa Indonesia"
        case "ar": return "العربية"
        case "tr": return "Türkçe"
        case "nl": return "Nederlands"
        default: return lang.uppercased()
        }
    }

}

// MARK: - Text Input Sheet

private struct TextInputSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingDisplay = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(appState.userLocale.flag)
                            Text(appState.userLocale.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.FG.secondary)
                        }
                        TextEditor(text: $viewModel.input)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Theme.BG.sunken)
                            )
                            .font(.system(size: 17))
                    }

                    Button {
                        Task {
                            await viewModel.translateStream(
                                source: appState.userLocale.language,
                                target: appState.destination.language,
                                polish: appState.culturalPolish
                            )
                        }
                    } label: {
                        Group {
                            if viewModel.loadingTranslate {
                                ProgressView().tint(.white)
                            } else {
                                Label("翻译", systemImage: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.Accent.gradient)
                        )
                        .designShadow(Theme.Shadow.accent)
                    }
                    .disabled(viewModel.input.isEmpty || viewModel.loadingTranslate)
                    .buttonStyle(.plain)

                    if !viewModel.liveTranslation.isEmpty || viewModel.result != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text(appState.destination.flag)
                                Text(appState.destination.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.Accent.deep)
                            }
                            Text(viewModel.result?.translatedText ?? viewModel.liveTranslation)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.FG.primary)

                            if let note = viewModel.result?.culturalNote, !note.isEmpty {
                                Label(note, systemImage: "lightbulb")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Chip.vanilla.fg)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Theme.Chip.vanilla.bg)
                                    )
                            }

                            HStack(spacing: 8) {
                                Button {
                                    let text = viewModel.result?.translatedText ?? viewModel.liveTranslation
                                    SpeechService.shared.speak(text, languageCode: appState.destination.voiceLanguage)
                                } label: {
                                    Label("朗读", systemImage: "speaker.wave.2.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Theme.Accent.base))
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.result?.translatedText.isEmpty ?? true)

                                if viewModel.result != nil {
                                    Button {
                                        showingDisplay = true
                                    } label: {
                                        Label("展示", systemImage: "tv")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Theme.FG.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule().strokeBorder(
                                                    Theme.FG.primary.opacity(0.1),
                                                    lineWidth: 0.5
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.Accent.soft)
                        )
                    }

                    if let err = viewModel.translateError {
                        Text("错误：\(err)")
                            .font(.footnote)
                            .foregroundStyle(Theme.Semantic.danger)
                    }
                }
                .padding(20)
            }
            .background(Theme.BG.base.ignoresSafeArea())
            .navigationTitle("文字翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDisplay) {
                if let r = viewModel.result {
                    FullScreenDisplayView(source: viewModel.input, target: r.translatedText)
                }
            }
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var loadingTranslate = false
    @Published var result: TranslationResult?
    @Published var liveTranslation: String = ""
    @Published var translateError: String?

    /// 流式文本翻译：走 /api/v1/translate/stream。
    func translateStream(source: String, target: String, polish: Bool) async {
        guard !input.isEmpty else { return }
        loadingTranslate = true
        translateError = nil
        result = nil
        liveTranslation = ""

        let stream = TranslateStreamService.stream(
            sourceText: input,
            sourceLanguage: source,
            targetLanguage: target,
            polish: polish
        )
        do {
            for try await event in stream {
                switch event {
                case .status:
                    break
                case .delta(let text):
                    liveTranslation += text
                case .final(let payload):
                    result = TranslationResult(
                        translatedText: payload.translatedText,
                        transliteration: nil,
                        confidence: 0.95,
                        engine: payload.engine,
                        cached: false,
                        culturalNote: payload.culturalNote
                    )
                    HistoryStore.shared.addText(
                        source: input,
                        translated: payload.translatedText,
                        sourceLanguage: source,
                        targetLanguage: target,
                        culturalNote: payload.culturalNote
                    )
                case .error(let msg):
                    translateError = msg
                }
            }
        } catch {
            translateError = error.localizedDescription
        }
        loadingTranslate = false
    }
}
