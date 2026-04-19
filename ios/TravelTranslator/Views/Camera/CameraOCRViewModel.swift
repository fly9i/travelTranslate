import SwiftUI
import UIKit

/// 拍照翻译详情页的视图模型：承载一张 OCRSnapshot + 流式日志 / 错误态。
///
/// 有两种使用方式：
/// - `init(initialImage:)` — 首页拍照 / 相册选图后进入，详情页 `.task` 时触发
///   `start(appState:)` 开始本地 OCR + 流式视觉翻译。
/// - `init(snapshot:)` — 从历史记录进入，已有完整 snapshot，不再启动流。
@MainActor
final class CameraOCRViewModel: ObservableObject {
    @Published var snapshot: OCRSnapshot
    @Published var streamLog: [String] = []
    @Published var ocrError: String?
    @Published var isStreaming: Bool = false

    private var hasStarted = false
    private let autoStart: Bool

    init(snapshot: OCRSnapshot) {
        self.snapshot = snapshot
        self.autoStart = false
    }

    init(initialImage: UIImage) {
        self.snapshot = OCRSnapshot(
            originalImage: initialImage,
            composedImage: initialImage,
            rawBlocks: [],
            items: [],
            sceneType: nil,
            summary: nil
        )
        self.autoStart = true
    }

    /// 幂等入口：详情页 `.task` 里调用，只启动一次。非 auto 模式（历史回放）直接跳过。
    func startIfNeeded(appState: AppState) {
        guard autoStart, !hasStarted else { return }
        hasStarted = true
        Task { await run(appState: appState) }
    }

    private func run(appState: AppState) async {
        isStreaming = true
        defer { isStreaming = false }

        appendLog("正在识别文字…")
        let recognized: [OCRBlock]
        do {
            recognized = try await OCRService.recognizeText(in: snapshot.originalImage)
        } catch {
            ocrError = error.localizedDescription
            return
        }
        if recognized.isEmpty {
            ocrError = "未识别到文字"
            return
        }

        snapshot.rawBlocks = recognized

        appendLog("OCR 完成 \(recognized.count) 块，正在上传图片…")
        let blocks = recognized.enumerated().map { idx, b in
            // Vision bbox: 左下原点 0-1 → 转换为左上原点 0-1，给后端 prompt 用更直观的坐标
            let v = b.boundingBox
            let bbox = VisionTranslateStreamService.OCRBlockPayload.BBox(
                x: Double(v.minX),
                y: Double(1 - v.maxY),
                w: Double(v.width),
                h: Double(v.height)
            )
            return VisionTranslateStreamService.OCRBlockPayload(
                index: idx,
                text: b.originalText,
                bbox: bbox
            )
        }
        let stream = VisionTranslateStreamService.stream(
            image: snapshot.originalImage,
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
                        originalImage: snapshot.originalImage
                    )
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
            unionBoxes.append(bbox ?? .zero)
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
