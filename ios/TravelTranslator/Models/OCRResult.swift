import UIKit

/// 一次 OCR + 翻译 + 场景理解的完整结果。首页和详情页共享。
struct OCRSnapshot: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    let composedImage: UIImage  // 原图 + 译文覆盖后的合成图
    let blocks: [OCRBlock]
    var description: VisionDescribeResult?
    let createdAt: Date = Date()
}
