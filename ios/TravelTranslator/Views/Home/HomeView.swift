import PhotosUI
import SwiftUI

/// 首页：主打拍 everything，次要功能是输入翻译 + 对话。
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingDestinationPicker = false
    @State private var showingCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                capturePanel
                if !viewModel.streamLog.isEmpty {
                    streamLogView
                }
                if let error = viewModel.ocrError {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                if let snapshot = viewModel.latestSnapshot {
                    latestResultCard(snapshot)
                }

                Divider().padding(.vertical, 4)

                quickTranslatePanel

                NavigationLink {
                    ConversationView()
                } label: {
                    Label("进入实时对话模式", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("TravelTranslator")
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selection: $appState.destination)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(
                onImage: { image in
                    showingCamera = false
                    Task { await viewModel.process(image: image, appState: appState) }
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.process(image: image, appState: appState)
                }
                pickerItem = nil
            }
        }
        .task {
            await appState.bootstrapFromLocation()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(appState.userLocale.flag).font(.title2)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            Button {
                showingDestinationPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(appState.destination.flag).font(.title2)
                    Text(appState.destination.name).bold()
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(.primary)
            }
            Spacer()
            Toggle("", isOn: $appState.culturalPolish)
                .labelsHidden()
                .toggleStyle(.switch)
            Text("润色").font(.caption)
        }
    }

    private var capturePanel: some View {
        VStack(spacing: 8) {
            Text("拍 everything，自动翻译 + 解说")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Button {
                    showingCamera = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill").font(.system(size: 36))
                        Text("拍照翻译").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.75)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle").font(.title2)
                        Text("相册").font(.caption)
                    }
                    .frame(width: 88)
                    .padding(.vertical, 24)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 流式状态：最多展示最后两行，窄灰底滚动感。
    private var streamLogView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.streamLog.suffix(2).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func latestResultCard(_ snapshot: OCRSnapshot) -> some View {
        NavigationLink {
            CameraOCRView(snapshot: snapshot)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: snapshot.composedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if let summary = snapshot.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                HStack {
                    Spacer()
                    Label("查看详情", systemImage: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var quickTranslatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即时翻译").font(.headline)
            TextField("说点什么 / 输入要翻译的内容…", text: $viewModel.input)
                .textFieldStyle(.roundedBorder)
            Button {
                Task {
                    await viewModel.translateStream(
                        source: appState.userLocale.language,
                        target: appState.destination.language,
                        polish: appState.culturalPolish
                    )
                }
            } label: {
                if viewModel.loadingTranslate {
                    ProgressView()
                } else {
                    Label("翻译", systemImage: "paperplane.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.input.isEmpty || viewModel.loadingTranslate)

            if !viewModel.liveTranslation.isEmpty || viewModel.result != nil {
                resultCard(
                    source: viewModel.input,
                    liveText: viewModel.liveTranslation,
                    result: viewModel.result
                )
            }
            if let error = viewModel.translateError {
                Text("错误：\(error)").foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private func resultCard(
        source: String,
        liveText: String,
        result: TranslationResult?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source).foregroundStyle(.secondary)
            Text(result?.translatedText ?? liveText).font(.title3).bold()
            if let note = result?.culturalNote, !note.isEmpty {
                Label(note, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Spacer()
                if let result {
                    NavigationLink {
                        FullScreenDisplayView(source: source, target: result.translatedText)
                    } label: {
                        Label("展示给对方", systemImage: "tv")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

        // 1) 本地 OCR
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

        // 2) 初始 snapshot：还没翻译，先放原图
        var snapshot = OCRSnapshot(
            originalImage: image,
            composedImage: image,
            rawBlocks: recognized,
            items: [],
            sceneType: nil,
            summary: nil
        )
        latestSnapshot = snapshot

        // 3) 调流式视觉翻译
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
                    // 只显示最后 60 个字符，模拟滚动
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

    /// 把 LLM final 结果落地：按 ocr_indices 合并原始 bbox，生成标注图。
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

    /// 把多个 OCR 块的 Vision 归一化 bbox 合并成一个外接矩形。
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
