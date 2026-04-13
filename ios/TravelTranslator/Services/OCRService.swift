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
    /// 翻译完成前，先把 OCR 识别到的区域高亮出来，让用户马上看到进展。
    static func composePreview(image: UIImage, blocks: [OCRBlock]) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.9).cgColor)
            cg.setFillColor(UIColor.systemYellow.withAlphaComponent(0.15).cgColor)
            cg.setLineWidth(max(2, size.width * 0.003))
            for block in blocks {
                let rect = pixelRect(for: block.boundingBox, imageSize: size)
                let padded = rect.insetBy(dx: -rect.width * 0.04, dy: -rect.height * 0.15)
                let path = UIBezierPath(roundedRect: padded, cornerRadius: padded.height * 0.15)
                cg.addPath(path.cgPath)
                cg.drawPath(using: .fillStroke)
            }
        }
    }

    /// 把原图和译文块合成为一张新图。
    /// 背景色通过 bbox 外环采样得到（排除文字像素），文字带对比描边，
    /// 仅对紧贴文字的矩形做半透明覆盖，尽量还原"直接替换原文"的观感。
    static func compose(image: UIImage, blocks: [OCRBlock]) -> UIImage {
        guard let cgInput = image.cgImage else { return image }
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))

            let cg = ctx.cgContext
            for block in blocks {
                guard let translation = block.translatedText,
                      !translation.isEmpty else { continue }

                let rect = pixelRect(for: block.boundingBox, imageSize: size)
                let padded = rect.insetBy(dx: -rect.width * 0.03, dy: -rect.height * 0.12)

                let bgColor = sampleOuterRingColor(
                    cgImage: cgInput,
                    around: padded,
                    imageSize: size
                )
                let textColor = contrastingColor(for: bgColor)
                let strokeColor = contrastingColor(for: textColor)

                // 用 bbox 外环估出的背景色做半透明覆盖，既盖住原文又不完全遮挡原图
                cg.saveGState()
                let clipPath = UIBezierPath(
                    roundedRect: padded,
                    cornerRadius: padded.height * 0.15
                )
                cg.addPath(clipPath.cgPath)
                cg.setFillColor(bgColor.withAlphaComponent(0.82).cgColor)
                cg.fillPath()
                cg.restoreGState()

                drawText(
                    translation,
                    in: padded,
                    color: textColor,
                    strokeColor: strokeColor,
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

    /// 采样 bbox 外环（上/下/左/右四条）的平均颜色，排除文字像素本身，
    /// 这样得到的背景色不会被原文字颜色"拉灰"。
    private static func sampleOuterRingColor(
        cgImage: CGImage,
        around rect: CGRect,
        imageSize: CGSize
    ) -> UIColor {
        let bounds = CGRect(origin: .zero, size: imageSize)
        let ringW = max(rect.height * 0.4, 8)
        let top = CGRect(x: rect.minX, y: rect.minY - ringW, width: rect.width, height: ringW)
        let bottom = CGRect(x: rect.minX, y: rect.maxY, width: rect.width, height: ringW)
        let left = CGRect(x: rect.minX - ringW, y: rect.minY, width: ringW, height: rect.height)
        let right = CGRect(x: rect.maxX, y: rect.minY, width: ringW, height: rect.height)

        let ci = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: NSNull()])

        var rSum: CGFloat = 0, gSum: CGFloat = 0, bSum: CGFloat = 0
        var weightSum: CGFloat = 0

        for ring in [top, bottom, left, right] {
            let clipped = ring.intersection(bounds)
            guard clipped.width > 1, clipped.height > 1 else { continue }
            let flipped = CGRect(
                x: clipped.minX,
                y: imageSize.height - clipped.maxY,
                width: clipped.width,
                height: clipped.height
            )
            guard let filter = CIFilter(name: "CIAreaAverage") else { continue }
            filter.setValue(ci, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: flipped), forKey: "inputExtent")
            guard let output = filter.outputImage else { continue }
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(
                output,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            let weight = clipped.width * clipped.height
            rSum += CGFloat(bitmap[0]) / 255 * weight
            gSum += CGFloat(bitmap[1]) / 255 * weight
            bSum += CGFloat(bitmap[2]) / 255 * weight
            weightSum += weight
        }

        guard weightSum > 0 else { return .white }
        return UIColor(
            red: rSum / weightSum,
            green: gSum / weightSum,
            blue: bSum / weightSum,
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
    /// 通过负 strokeWidth 同时填充和描边，让文字在任意底图上都清晰可读。
    private static func drawText(
        _ text: String,
        in rect: CGRect,
        color: UIColor,
        strokeColor: UIColor,
        context: CGContext
    ) {
        var fontSize = rect.height * 0.75
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .strokeColor: strokeColor,
            .strokeWidth: -3.0,
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
