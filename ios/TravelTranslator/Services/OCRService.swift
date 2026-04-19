import CoreImage
import SwiftUI
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
    /// 根据应用侧的短语言代码 (ja/ko/zh/...) 映射到 Vision 的 BCP-47 tag。
    /// 始终追加 en-US 作 fallback（菜单 / 路牌常混排拉丁字母）。
    /// Vision Revision3 (iOS 16+) 支持：
    ///   ja-JP, ko-KR, zh-Hans, zh-Hant, en-US, fr-FR, de-DE, es-ES, it-IT,
    ///   pt-BR, ru-RU, uk-UA, th-TH, vi-VT, ar-SA 等。
    static func recognitionLanguages(for appCode: String?) -> [String] {
        var tags: [String] = []
        switch (appCode ?? "").lowercased() {
        case "ja":
            tags = ["ja-JP"]
        case "ko":
            tags = ["ko-KR"]
        case "zh", "zh-hans", "zh-cn":
            tags = ["zh-Hans", "zh-Hant"]
        case "zh-hant", "zh-tw", "zh-hk":
            tags = ["zh-Hant", "zh-Hans"]
        case "en":
            tags = ["en-US"]
        case "fr":
            tags = ["fr-FR"]
        case "de":
            tags = ["de-DE"]
        case "es":
            tags = ["es-ES"]
        case "it":
            tags = ["it-IT"]
        case "pt":
            tags = ["pt-BR"]
        case "ru":
            tags = ["ru-RU"]
        case "uk":
            tags = ["uk-UA"]
        case "th":
            tags = ["th-TH"]
        case "vi":
            tags = ["vi-VT"]
        case "ar":
            tags = ["ar-SA"]
        default:
            tags = []
        }
        if !tags.contains("en-US") {
            tags.append("en-US")
        }
        return tags
    }

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
            // 放开小字过滤：菜单/路牌常有相对高度很小的描述行，默认阈值会被丢掉
            request.minimumTextHeight = 0
            // 显式使用最新修订版（iOS 16+ 精度更高）
            if #available(iOS 16.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }
            // 只保留 Vision 当前 revision 实际支持的 tag —— 传不支持的 tag 会让整个请求失败。
            let supported: Set<String> = {
                if #available(iOS 16.0, *) {
                    return Set((try? VNRecognizeTextRequest.supportedRecognitionLanguages(
                        for: .accurate,
                        revision: VNRecognizeTextRequestRevision3
                    )) ?? [])
                }
                return Set((try? VNRecognizeTextRequest.supportedRecognitionLanguages(
                    for: .accurate,
                    revision: VNRecognizeTextRequestRevision2
                )) ?? [])
            }()
            let requested = languages.isEmpty ? ["en-US"] : languages
            let filtered = requested.filter { supported.contains($0) }
            request.recognitionLanguages = filtered.isEmpty ? ["en-US"] : filtered

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

/// 跨 UIKit / SwiftUI 的配色板：每个 OCR 文本块按下标取固定颜色，
/// 这样图像上的框线、编号圆点 和 下方对照列表里的徽章能一一对应。
enum OCRBlockPalette {
    private static let uiColors: [UIColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemTeal,
        .systemBlue,
        .systemIndigo,
        .systemPurple,
        .systemPink,
        .systemBrown,
    ]

    static func uiColor(at index: Int) -> UIColor {
        uiColors[((index % uiColors.count) + uiColors.count) % uiColors.count]
    }

    static func color(at index: Int) -> Color {
        Color(uiColor(at: index))
    }
}

/// 把 OCR 文本块"标注"到原图上：给每个块画一个对应颜色的矩形框，
/// 并在框的左上角压一个实心圆点 + 编号，方便用户和下方译文对照。
enum OCRCompositor {
    /// 兼容旧 API：直接从 OCRBlock 数组标注。
    static func annotate(image: UIImage, blocks: [OCRBlock]) -> UIImage {
        annotate(image: image, boxes: blocks.map { $0.boundingBox })
    }

    /// 给定 Vision 归一化 bbox 数组，在原图上画彩色框 + 编号徽章。按下标取色。
    static func annotate(image: UIImage, boxes: [CGRect]) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let shortEdge = min(size.width, size.height)
        let lineWidth = max(2, shortEdge * 0.005)

        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext

            for (idx, bbox) in boxes.enumerated() {
                if bbox == .zero { continue }
                let color = OCRBlockPalette.uiColor(at: idx)
                let rect = pixelRect(for: bbox, imageSize: size)
                let padded = rect.insetBy(dx: -rect.width * 0.03, dy: -rect.height * 0.15)

                // 1) 框线
                cg.saveGState()
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(lineWidth)
                let path = UIBezierPath(
                    roundedRect: padded,
                    cornerRadius: padded.height * 0.12
                )
                cg.addPath(path.cgPath)
                cg.strokePath()
                cg.restoreGState()

                // 2) 左上角的圆点 + 编号
                drawBadge(
                    number: idx + 1,
                    at: CGPoint(x: padded.minX, y: padded.minY),
                    color: color,
                    shortEdge: shortEdge,
                    context: cg
                )
            }
        }
    }

    /// Vision bbox（左下原点 0-1）→ 图像像素矩形（左上原点）。
    private static func pixelRect(for bbox: CGRect, imageSize: CGSize) -> CGRect {
        let x = bbox.minX * imageSize.width
        let y = (1 - bbox.maxY) * imageSize.height
        let w = bbox.width * imageSize.width
        let h = bbox.height * imageSize.height
        return CGRect(x: x, y: y, width: w, height: h).integral
    }

    /// 画一个带编号的实心徽章。圆心压在 (cx, cy)，一半在框内一半在框外。
    /// 两位数自动切换到胶囊形避免文字溢出。
    private static func drawBadge(
        number: Int,
        at center: CGPoint,
        color: UIColor,
        shortEdge: CGFloat,
        context cg: CGContext
    ) {
        let radius = max(14, shortEdge * 0.022)
        let label = "\(number)" as NSString
        let fontSize = radius * 1.15
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: UIColor.white,
        ]
        let textSize = label.size(withAttributes: attrs)

        // 两位以上数字用胶囊形
        let badgeWidth = max(radius * 2, textSize.width + radius * 0.9)
        let badgeHeight = radius * 2
        let badgeRect = CGRect(
            x: center.x - badgeWidth / 2,
            y: center.y - badgeHeight / 2,
            width: badgeWidth,
            height: badgeHeight
        )

        cg.saveGState()
        cg.setFillColor(color.cgColor)
        cg.setStrokeColor(UIColor.white.cgColor)
        cg.setLineWidth(max(1.5, shortEdge * 0.0025))
        let badgePath = UIBezierPath(
            roundedRect: badgeRect,
            cornerRadius: badgeHeight / 2
        )
        cg.addPath(badgePath.cgPath)
        cg.drawPath(using: .fillStroke)
        cg.restoreGState()

        UIGraphicsPushContext(cg)
        let textOrigin = CGPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        label.draw(at: textOrigin, withAttributes: attrs)
        UIGraphicsPopContext()
    }
}
