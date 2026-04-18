import PhotosUI
import SwiftUI

/// 首页 / 相机 Tab —— 沉浸式取景器风格首屏。
/// 顶部国旗切换 + 模式分段；中央取景框指引；底部大快门 + 相册 + 麦克风；上滑拉起文字输入。
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()

    @State private var showingDestinationPicker = false
    @State private var showingSettings = false
    @State private var showingCamera = false
    @State private var showingConversation = false
    @State private var showingTextPanel = false
    @State private var showingOCRDetail = false
    @State private var mode: CaptureMode = .photo
    @State private var flashOn = false
    @State private var pickerItem: PhotosPickerItem?

    enum CaptureMode: String, CaseIterable {
        case photo, live, text, conversation
        var label: String {
            switch self {
            case .photo: return "拍照"
            case .live: return "实时"
            case .text: return "文本"
            case .conversation: return "对话"
            }
        }
    }

    var body: some View {
        ZStack {
            viewfinderBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                modeSegment
                    .padding(.top, 12)

                Spacer(minLength: 0)

                framingGuide

                Spacer(minLength: 0)

                textHint
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                shutterDock
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96) // 给浮动 TabBar 留位置
            }

            if !viewModel.streamLog.isEmpty || viewModel.ocrError != nil {
                VStack {
                    statusToast
                        .padding(.top, 120)
                    Spacer()
                }
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
                    Task {
                        await viewModel.process(image: image, appState: appState)
                        if viewModel.latestSnapshot != nil {
                            showingOCRDetail = true
                        }
                    }
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingConversation) {
            NavigationStack { ConversationView() }
        }
        .navigationDestination(isPresented: $showingOCRDetail) {
            if let snap = viewModel.latestSnapshot {
                CameraOCRView(snapshot: snap)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.process(image: image, appState: appState)
                    if viewModel.latestSnapshot != nil {
                        showingOCRDetail = true
                    }
                }
                pickerItem = nil
            }
        }
        .task {
            await appState.bootstrapFromLocation()
        }
    }

    // MARK: - Pieces

    /// 模拟取景器的背景：深色渐变 + 柔光 + 远景建筑意象，替代真实预览的"霸屏感"，
    /// 点击快门即拉起系统相机。
    private var viewfinderBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B0615), Color(hex: 0x2A1820), Color(hex: 0x1A0F18)],
                startPoint: .top, endPoint: .bottom
            )
            // 珊瑚暖光
            RadialGradient(
                colors: [Color(hex: 0xFF9E5E).opacity(0.35), .clear],
                center: .init(x: 0.25, y: 0.4), startRadius: 20, endRadius: 320
            )
            RadialGradient(
                colors: [Color(hex: 0xFFD8A8).opacity(0.22), .clear],
                center: .init(x: 0.8, y: 0.45), startRadius: 20, endRadius: 280
            )
            // 暗角
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.45)],
                center: .center, startRadius: 180, endRadius: 520
            )
        }
    }

    private var topChrome: some View {
        HStack {
            GlassPillButton(systemImage: "gearshape", size: 40) {
                showingSettings = true
            }
            Spacer()
            LangPairPill(
                fromFlag: appState.userLocale.flag,
                toFlag: appState.destination.flag,
                toName: appState.destination.name,
                onTap: { showingDestinationPicker = true },
                overlay: true
            )
            Spacer()
            GlassPillButton(
                systemImage: flashOn ? "bolt.fill" : "bolt.slash",
                size: 40
            ) {
                flashOn.toggle()
            }
        }
    }

    private var modeSegment: some View {
        HStack(spacing: 3) {
            ForEach(CaptureMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        mode = m
                        if m == .text { showingTextPanel = true }
                        if m == .conversation { showingConversation = true }
                    }
                } label: {
                    Text(m.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(m == mode ? Color.black : Color.white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            ZStack {
                                if m == mode {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.white)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var framingGuide: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .ignoresSafeArea()
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .frame(width: 260, height: 200)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                        .frame(width: 260, height: 200)
                    FramingCorners()
                        .frame(width: 260, height: 200)
                }
                Text("将菜单 / 路牌 / 标签对准取景框")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 1)
            }
        }
    }

    private var textHint: some View {
        Button {
            showingTextPanel = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.85))
                Text("上滑输入文字翻译")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var shutterDock: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x9AB86C), Color(hex: 0x607A46)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showingCamera = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 78, height: 78)
                        .background(Circle().fill(.ultraThinMaterial))
                    Circle()
                        .fill(Theme.Accent.gradient)
                        .frame(width: 66, height: 66)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.Accent.glow, radius: 24, x: 0, y: 10)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showingConversation = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }

    private var statusToast: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let err = viewModel.ocrError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.white)
            } else if let line = viewModel.streamLog.last {
                HStack(spacing: 6) {
                    ProgressView().tint(.white).scaleEffect(0.7)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.black.opacity(0.55))
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Framing corner ticks (珊瑚橙四角)

private struct FramingCorners: View {
    private let tick: CGFloat = 18
    private let width: CGFloat = 260
    private let height: CGFloat = 200

    var body: some View {
        ZStack {
            corner(alignment: .topLeading)
            corner(alignment: .topTrailing)
            corner(alignment: .bottomLeading)
            corner(alignment: .bottomTrailing)
        }
        .frame(width: width, height: height)
    }

    private func corner(alignment: Alignment) -> some View {
        let flipX = alignment == .topTrailing || alignment == .bottomTrailing
        let flipY = alignment == .bottomLeading || alignment == .bottomTrailing
        return ZStack(alignment: .topLeading) {
            // 横线
            Rectangle()
                .fill(Theme.Accent.base)
                .frame(width: tick, height: 3)
                .offset(y: flipY ? tick - 3 : 0)
            // 竖线
            Rectangle()
                .fill(Theme.Accent.base)
                .frame(width: 3, height: tick)
                .offset(x: flipX ? tick - 3 : 0)
        }
        .frame(width: tick, height: tick)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
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

    @Published var latestSnapshot: OCRSnapshot?
    @Published var streamLog: [String] = []
    @Published var ocrError: String?

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

    /// 图片流程：本地 OCR → 流式调 LLM → 解析 final → 生成带彩色框的标注图。
    func process(image: UIImage, appState: AppState) async {
        ocrError = nil
        latestSnapshot = nil
        streamLog.removeAll()

        appendLog("正在识别文字…")
        let recognized: [OCRBlock]
        do {
            recognized = try await OCRService.recognizeText(in: image)
        } catch {
            ocrError = error.localizedDescription
            return
        }
        if recognized.isEmpty {
            ocrError = "未识别到文字"
            return
        }

        var snapshot = OCRSnapshot(
            originalImage: image,
            composedImage: image,
            rawBlocks: recognized,
            items: [],
            sceneType: nil,
            summary: nil
        )
        latestSnapshot = snapshot

        appendLog("OCR 完成 \(recognized.count) 块，正在上传图片…")
        let blocks = recognized.enumerated().map { idx, b in
            VisionTranslateStreamService.OCRBlockPayload(index: idx, text: b.originalText)
        }
        let stream = VisionTranslateStreamService.stream(
            image: image,
            blocks: blocks,
            sourceLanguage: appState.destination.language,
            targetLanguage: appState.userLocale.language,
            destination: appState.destination.name
        )

        var accumulatedDelta = ""
        do {
            for try await event in stream {
                switch event {
                case .status(let msg):
                    appendLog(msg)
                case .delta(let text):
                    accumulatedDelta += text
                    let tail = String(accumulatedDelta.suffix(60))
                    appendLog(tail)
                case .final(let payload):
                    snapshot = Self.applyFinal(
                        payload: payload,
                        snapshot: snapshot,
                        originalImage: image
                    )
                    latestSnapshot = snapshot
                    appendLog("完成：\(payload.items.count) 项")
                    HistoryStore.shared.addVision(
                        image: snapshot.composedImage,
                        items: snapshot.items,
                        sceneType: snapshot.sceneType,
                        summary: snapshot.summary
                    )
                case .error(let msg):
                    ocrError = msg
                }
            }
        } catch {
            ocrError = error.localizedDescription
        }
    }

    private func appendLog(_ line: String) {
        streamLog.append(line)
        if streamLog.count > 20 {
            streamLog.removeFirst(streamLog.count - 20)
        }
    }

    private static func applyFinal(
        payload: VisionTranslateFinal,
        snapshot: OCRSnapshot,
        originalImage: UIImage
    ) -> OCRSnapshot {
        let rawBlocks = snapshot.rawBlocks
        var items: [ResolvedTranslateItem] = []
        var unionBoxes: [CGRect] = []
        for item in payload.items {
            let bbox = unionBBox(indices: item.ocrIndices, blocks: rawBlocks)
            items.append(
                ResolvedTranslateItem(
                    sourceText: item.sourceText,
                    translatedText: item.translatedText,
                    note: item.note,
                    boundingBox: bbox ?? .zero
                )
            )
            if let bbox {
                unionBoxes.append(bbox)
            } else {
                unionBoxes.append(.zero)
            }
        }
        let composed = OCRCompositor.annotate(
            image: originalImage,
            boxes: unionBoxes
        )
        var next = snapshot
        next.composedImage = composed
        next.items = items
        next.sceneType = payload.sceneType
        next.summary = payload.summary
        return next
    }

    private static func unionBBox(indices: [Int], blocks: [OCRBlock]) -> CGRect? {
        var result: CGRect? = nil
        for i in indices where i >= 0 && i < blocks.count {
            let r = blocks[i].boundingBox
            if let current = result {
                result = current.union(r)
            } else {
                result = r
            }
        }
        return result
    }
}
