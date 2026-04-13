import UIKit

/// LLM 解析后的一个翻译项目，已经把相关 OCR 块合并并算出联合 bbox（Vision 坐标系）。
struct ResolvedTranslateItem: Identifiable {
    let id = UUID()
    let sourceText: String
    let translatedText: String
    let note: String?
    let boundingBox: CGRect
}

/// 一次拍照 → OCR → 流式视觉翻译的完整结果。首页和详情页共享。
struct OCRSnapshot: Identifiable {
    let id = UUID()
    let originalImage: UIImage
    var composedImage: UIImage  // 初始=原图；final 后替换为带彩色框 + 编号的标注图
    var rawBlocks: [OCRBlock]   // 端侧 OCR 原始块，按下标查 bbox
    var items: [ResolvedTranslateItem]
    var sceneType: String?
    var summary: String?
    let createdAt: Date = Date()
}
