import CoreImage
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

/// 把 OCR 文本块用译文"贴回"原图的合成器。
///
/// 方案（近似 Google 翻译相机）：
/// 1. 对每个文字 bbox 做扩张，采样 bbox 外侧环形区域像素，计算背景主色。
/// 2. 判断文字颜色（背景主色的反差色）。
/// 3. 用背景色填充 bbox（等于"抠掉"原文）。
/// 4. 用目标语言文本在同位置、同颜色、按 bbox 高度估算的字号渲染。
///
/// 纯色背景（菜单、路牌、说明牌）效果最好；复杂背景会有色块瑕疵。
enum OCRCompositor {
    /// 把原图和译文块合成为一张新图。
    static func compose(image: UIImage, blocks: [OCRBlock]) -> UIImage {
        guard let cgInput = image.cgImage else { return image }
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            // 1) 原图铺底
            image.draw(in: CGRect(origin: .zero, size: size))

            let cg = ctx.cgContext
            for block in blocks {
                guard let translation = block.translatedText,
                      !translation.isEmpty else { continue }

                let rect = pixelRect(for: block.boundingBox, imageSize: size)
                let padded = rect.insetBy(dx: -rect.width * 0.05, dy: -rect.height * 0.2)

                let bgColor = sampleBackgroundColor(cgImage: cgInput, around: padded, imageSize: size)
                let textColor = contrastingColor(for: bgColor)

                // 2) 用背景色填充 bbox 区域（抠掉原文）
                cg.saveGState()
                cg.setFillColor(bgColor.cgColor)
                cg.fill(padded)
                cg.restoreGState()

                // 3) 绘制译文
                drawText(
                    translation,
                    in: padded,
                    color: textColor,
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

    /// 采样 rect 周围环形区域的平均颜色，作为背景主色估计。
    private static func sampleBackgroundColor(
        cgImage: CGImage,
        around rect: CGRect,
        imageSize: CGSize
    ) -> UIColor {
        let expanded = rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.4)
        let clipped = expanded.intersection(CGRect(origin: .zero, size: imageSize))
        guard clipped.width > 1, clipped.height > 1 else {
            return .white
        }

        let ci = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        // CIImage 坐标是左下原点，转一下
        let flipped = CGRect(
            x: clipped.minX,
            y: imageSize.height - clipped.maxY,
            width: clipped.width,
            height: clipped.height
        )

        guard let filter = CIFilter(name: "CIAreaAverage") else { return .white }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: flipped), forKey: "inputExtent")
        guard let output = filter.outputImage else { return .white }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }

    /// 基于背景亮度选择前景文字颜色。
    private static func contrastingColor(for bg: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        // ITU-R BT.709 亮度
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma > 0.6 ? UIColor(white: 0.08, alpha: 1) : UIColor(white: 0.97, alpha: 1)
    }

    /// 把译文绘制进 rect：按 bbox 高度估字号，自动缩放 + 垂直居中。
    private static func drawText(
        _ text: String,
        in rect: CGRect,
        color: UIColor,
        context: CGContext
    ) {
        var fontSize = rect.height * 0.75
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
        ]

        // 如果太宽就按比例缩
        var textSize = (text as NSString).size(withAttributes: attrs)
        if textSize.width > rect.width && textSize.width > 0 {
            let ratio = rect.width / textSize.width
            fontSize = max(8, fontSize * ratio)
            attrs[.font] = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            textSize = (text as NSString).size(withAttributes: attrs)
        }

        let drawRect = CGRect(
            x: rect.minX + max(0, (rect.width - textSize.width) / 2),
            y: rect.minY + max(0, (rect.height - textSize.height) / 2),
            width: min(textSize.width, rect.width),
            height: textSize.height
        )

        UIGraphicsPushContext(context)
        (text as NSString).draw(in: drawRect, withAttributes: attrs)
        UIGraphicsPopContext()
    }
}
