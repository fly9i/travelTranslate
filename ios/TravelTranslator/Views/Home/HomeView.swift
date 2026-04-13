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
                if viewModel.loadingOCR {
                    ProgressView(viewModel.loadingMessage)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
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
                if let desc = snapshot.description {
                    Text(desc.summary)
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
                    await viewModel.translate(
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

            if let result = viewModel.result {
                resultCard(source: viewModel.input, result: result)
            }
            if let error = viewModel.translateError {
                Text("错误：\(error)").foregroundStyle(.red).font(.footnote)
            }
        }
    }

    private func resultCard(source: String, result: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source).foregroundStyle(.secondary)
            Text(result.translatedText).font(.title3).bold()
            if let tl = result.transliteration {
                Text(tl).font(.footnote).foregroundStyle(.secondary)
            }
            if let note = result.culturalNote, !note.isEmpty {
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
                NavigationLink {
                    FullScreenDisplayView(source: source, target: result.translatedText)
                } label: {
                    Label("展示给对方", systemImage: "tv")
                }
                .buttonStyle(.borderedProminent)
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
    @Published var translateError: String?

    @Published var latestSnapshot: OCRSnapshot?
    @Published var loadingOCR = false
    @Published var loadingMessage: String = ""
    @Published var ocrError: String?

    func translate(source: String, target: String, polish: Bool) async {
        guard !input.isEmpty else { return }
        loadingTranslate = true
        translateError = nil
        do {
            result = try await TranslationService.shared.translate(
                text: input,
                from: source,
                to: target,
                context: nil,
                polish: polish
            )
        } catch {
            translateError = error.localizedDescription
        }
        loadingTranslate = false
    }

    func process(image: UIImage, appState: AppState) async {
        loadingOCR = true
        ocrError = nil
        latestSnapshot = nil
        defer { loadingOCR = false }

        loadingMessage = "正在识别文字…"
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

        // 图像标注一次生成：每个块上加彩色框 + 编号，下方列表靠颜色对照
        let annotated = OCRCompositor.annotate(image: image, blocks: recognized)
        var snapshot = OCRSnapshot(
            originalImage: image,
            composedImage: annotated,
            blocks: recognized,
            description: nil
        )
        latestSnapshot = snapshot

        loadingMessage = "正在批量翻译 \(recognized.count) 条…"
        var blocks = recognized
        let texts = recognized.map { $0.originalText }
        let targetLang = appState.userLocale.language
        let sourceLang = appState.destination.language
        let destName = appState.destination.name

        async let translationTask = Self.runBatchTranslate(
            texts: texts,
            source: sourceLang,
            target: targetLang
        )
        async let descriptionTask = Self.runVisionDescribe(
            texts: texts,
            source: sourceLang,
            userLang: targetLang,
            destination: destName
        )

        let translations = await translationTask
        for (idx, tr) in translations.enumerated() where idx < blocks.count {
            blocks[idx].translatedText = tr
        }
        snapshot.blocks = blocks
        latestSnapshot = snapshot

        let desc = await descriptionTask
        if let desc {
            snapshot.description = desc
            latestSnapshot = snapshot
        }
    }

    private static func runBatchTranslate(
        texts: [String],
        source: String,
        target: String
    ) async -> [String] {
        do {
            return try await TranslationService.shared.translateBatch(
                texts: texts,
                from: source.isEmpty ? "auto" : source,
                to: target,
                context: nil
            )
        } catch {
            return texts
        }
    }

    private static func runVisionDescribe(
        texts: [String],
        source: String,
        userLang: String,
        destination: String
    ) async -> VisionDescribeResult? {
        do {
            return try await VisionDescribeService.shared.describe(
                ocrTexts: texts,
                sourceLanguage: source,
                userLanguage: userLang,
                destination: destination
            )
        } catch {
            return nil
        }
    }
}
