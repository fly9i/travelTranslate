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

/// 端侧 OCR：Vision 对大图会内部下采样，密排菜单小字常被吃掉。
/// 策略：整图 OCR 兜底 + 2×2 分块 OCR（带 20% 重叠）并行跑，
/// 把每个 tile 的归一化坐标映射回整图后合并去重。
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

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        async let fullTask: [OCRBlock] = recognize(cgImage: cgImage, languages: languages)

        let tiles = computeTiles(imageSize: imageSize, rows: 2, cols: 2, overlap: 0.2)

        var tileResults: [[OCRBlock]] = []
        try await withThrowingTaskGroup(of: [OCRBlock].self) { group in
            for tile in tiles {
                group.addTask {
                    guard let cropped = cgImage.cropping(to: tile) else { return [] }
                    let blocks = try await recognize(cgImage: cropped, languages: languages)
                    return mapTileBlocksToFullImage(
                        blocks: blocks, tile: tile, imageSize: imageSize
                    )
                }
            }
            for try await blocks in group {
                tileResults.append(blocks)
            }
        }

        let full = try await fullTask
        let merged = full + tileResults.flatMap { $0 }
        return dedupe(merged)
    }

    // MARK: - 单次 Vision 识别

    private static func recognize(
        cgImage: CGImage,
        languages: [String]
    ) async throws -> [OCRBlock] {
        try await withCheckedThrowingContinuation { cont in
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
            request.recognitionLanguages = languages.isEmpty
                ? ["en-US", "zh-Hans"]
                : languages

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

    // MARK: - 分块辅助

    /// 返回像素矩形（左上原点）。每块在相邻方向上外扩 overlap，避免切到字。
    private static func computeTiles(
        imageSize: CGSize,
        rows: Int,
        cols: Int,
        overlap: CGFloat
    ) -> [CGRect] {
        let tileW = imageSize.width / CGFloat(cols)
        let tileH = imageSize.height / CGFloat(rows)
        let padX = tileW * overlap
        let padY = tileH * overlap
        var tiles: [CGRect] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let raw = CGRect(
                    x: CGFloat(c) * tileW - padX,
                    y: CGFloat(r) * tileH - padY,
                    width: tileW + padX * 2,
                    height: tileH + padY * 2
                )
                let clamped = raw
                    .intersection(CGRect(origin: .zero, size: imageSize))
                    .integral
                if clamped.width > 1, clamped.height > 1 {
                    tiles.append(clamped)
                }
            }
        }
        return tiles
    }

    /// Tile 内 Vision 归一化 bbox（左下原点 0-1）→ 整图归一化 bbox。
    private static func mapTileBlocksToFullImage(
        blocks: [OCRBlock],
        tile: CGRect,
        imageSize: CGSize
    ) -> [OCRBlock] {
        let tw = tile.width / imageSize.width
        let th = tile.height / imageSize.height
        let tx = tile.minX / imageSize.width
        // tile 是像素矩形（左上原点），其底边在 Vision（左下原点）里的 y 是：
        let tyBottom = (imageSize.height - tile.maxY) / imageSize.height
        return blocks.map { b in
            let bb = b.boundingBox
            let newBBox = CGRect(
                x: tx + bb.minX * tw,
                y: tyBottom + bb.minY * th,
                width: bb.width * tw,
                height: bb.height * th
            )
            return OCRBlock(
                originalText: b.originalText,
                translatedText: nil,
                boundingBox: newBBox
            )
        }
    }

    /// 同（规范化后）文字 + IoU>0.3 视为同一块，保留面积更大的。
    private static func dedupe(_ blocks: [OCRBlock]) -> [OCRBlock] {
        var kept: [OCRBlock] = []
        for b in blocks {
            let key = normalize(b.originalText)
            var duplicateIndex: Int?
            for (i, k) in kept.enumerated() where normalize(k.originalText) == key {
                if iou(b.boundingBox, k.boundingBox) > 0.3 {
                    duplicateIndex = i
                    break
                }
            }
            if let idx = duplicateIndex {
                if area(b.boundingBox) > area(kept[idx].boundingBox) {
                    kept[idx] = b
                }
            } else {
                kept.append(b)
            }
        }
        return kept
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func area(_ r: CGRect) -> CGFloat {
        max(0, r.width) * max(0, r.height)
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull || inter.isEmpty { return 0 }
        let interArea = area(inter)
        let unionArea = area(a) + area(b) - interArea
        guard unionArea > 0 else { return 0 }
        return interArea / unionArea
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
