import PhotosUI
import SwiftUI

/// 拍照/选照片翻译。当前只支持从相册选择。
struct CameraOCRView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CameraOCRViewModel()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("从相册选择照片", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: pickerItem) { _, newItem in
                    Task { await loadImage(newItem) }
                }

                if viewModel.loading {
                    ProgressView(viewModel.loadingMessage)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let error = viewModel.error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                if let image = viewModel.image {
                    imageWithOverlay(image)
                }

                if !viewModel.blocks.isEmpty {
                    blocksList
                }
            }
            .padding()
        }
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            viewModel.error = "无法加载图片"
            return
        }
        await viewModel.process(image: image, target: appState.destination.language)
    }

    private func imageWithOverlay(_ image: UIImage) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                let fitted = fittedRect(imageSize: image.size, container: geo.size)
                ForEach(viewModel.blocks) { block in
                    overlayLabel(block, fitted: fitted)
                }
            }
        }
        .aspectRatio(image.size, contentMode: .fit)
    }

    // Vision 坐标：左下原点，0-1 归一化；转到 SwiftUI（左上原点）并缩放到图像实际显示区域。
    private func fittedRect(imageSize: CGSize, container: CGSize) -> CGRect {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func overlayLabel(_ block: OCRBlock, fitted: CGRect) -> some View {
        let bb = block.boundingBox
        let x = fitted.minX + bb.minX * fitted.width
        let y = fitted.minY + (1 - bb.maxY) * fitted.height
        let w = bb.width * fitted.width
        let h = bb.height * fitted.height
        return Text(block.translatedText ?? block.originalText)
            .font(.system(size: max(9, h * 0.6)))
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 2)
            .frame(width: w, height: h, alignment: .center)
            .background(Color.yellow.opacity(0.85))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .position(x: x + w / 2, y: y + h / 2)
    }

    private var blocksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别结果").font(.headline)
            ForEach(viewModel.blocks) { block in
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.originalText).font(.body)
                    if let tr = block.translatedText {
                        Text(tr).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

@MainActor
final class CameraOCRViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var blocks: [OCRBlock] = []
    @Published var loading = false
    @Published var loadingMessage = ""
    @Published var error: String?

    func process(image: UIImage, target: String) async {
        self.image = image
        self.blocks = []
        self.error = nil
        self.loading = true
        defer { self.loading = false }

        do {
            loadingMessage = "正在识别文字…"
            let recognized = try await OCRService.recognizeText(in: image)
            if recognized.isEmpty {
                self.error = "未识别到文字"
                return
            }
            self.blocks = recognized

            loadingMessage = "正在翻译…"
            await withTaskGroup(of: (UUID, String?).self) { group in
                for block in recognized {
                    group.addTask {
                        do {
                            let result = try await TranslationService.shared.translate(
                                text: block.originalText,
                                to: target,
                                context: nil
                            )
                            return (block.id, result.translatedText)
                        } catch {
                            return (block.id, nil)
                        }
                    }
                }
                for await (id, translation) in group {
                    if let translation, let idx = self.blocks.firstIndex(where: { $0.id == id }) {
                        self.blocks[idx].translatedText = translation
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
