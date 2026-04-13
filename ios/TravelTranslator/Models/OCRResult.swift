import UIKit

/// 一次 OCR + 翻译 + 场景理解的完整结果。首页和详情页共享。
struct OCRSnapshot: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    let composedImage: UIImage  // 原图 + 彩色框 + 编号徽章 的标注图
    var blocks: [OCRBlock]
    var description: VisionDescribeResult?
    let createdAt: Date = Date()
}
