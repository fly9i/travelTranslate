import UIKit
import Vision

/// 识别到的文字块 + 译文 + 归一化坐标（0-1, Vision 原始坐标系：左下原点）。
struct OCRBlock: Identifiable {
    let id = UUID()
    let originalText: String
    var translatedText: String?
    let boundingBox: CGRect
}

/// 端侧 OCR：用 Vision VNRecognizeTextRequest 识别图像中的文字。
enum OCRService {
    /// 识别图像中的文字块。recognitionLanguages 示例：["ja-JP", "zh-Hans"]。
    static func recognizeText(
        in image: UIImage,
        languages: [String] = []
    ) async throws -> [OCRBlock] {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "OCRService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法读取图像数据"
            ])
        }

        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = observations.compactMap { obs -> OCRBlock? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return OCRBlock(
                        originalText: text,
                        translatedText: nil,
                        boundingBox: obs.boundingBox
                    )
                }
                cont.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !languages.isEmpty {
                request.recognitionLanguages = languages
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
