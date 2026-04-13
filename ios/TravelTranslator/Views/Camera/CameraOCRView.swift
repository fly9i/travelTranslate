import SwiftUI

/// 拍照 / 相册 翻译结果详情页。从首页 NavigationLink 过来。
struct CameraOCRView: View {
    let snapshot: OCRSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(uiImage: snapshot.composedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let desc = snapshot.description {
                    VisionDescriptionCard(result: desc)
                }

                Text("原文 / 译文对照（\(snapshot.blocks.count) 条）")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(snapshot.blocks.enumerated()), id: \.element.id) { idx, block in
                        OCRBlockRow(index: idx, block: block)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 单条 OCR 原文 / 译文对照行：左侧是带编号的彩色圆点徽章，颜色与图像上的框一致。
struct OCRBlockRow: View {
    let index: Int
    let block: OCRBlock

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NumberBadge(number: index + 1, color: OCRBlockPalette.color(at: index))
            VStack(alignment: .leading, spacing: 4) {
                Text(block.originalText)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let tr = block.translatedText, !tr.isEmpty {
                    Text(tr)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("翻译中…")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 和图像上的徽章同色同形的编号小圆点。两位数自动胶囊化。
struct NumberBadge: View {
    let number: Int
    let color: Color

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, number >= 10 ? 6 : 0)
            .background(color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white, lineWidth: 1.5)
            )
    }
}

/// 场景理解结果卡片。
struct VisionDescriptionCard: View {
    let result: VisionDescribeResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: sceneIcon(result.sceneType))
                Text(sceneLabel(result.sceneType)).font(.headline)
                Spacer()
            }
            Text(result.summary).font(.callout)

            if !result.items.isEmpty {
                Divider()
                ForEach(result.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.subheadline).bold()
                            if let og = item.original, og != item.name {
                                Text("（\(og)）").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let desc = item.description {
                            Text(desc).font(.caption).foregroundStyle(.secondary)
                        }
                        if !item.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(item.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        if let rec = item.recommendation {
                            Text(rec).font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !result.warnings.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.warnings, id: \.self) { w in
                        Label(w, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sceneIcon(_ type: String) -> String {
        switch type {
        case "menu": return "fork.knife"
        case "sign": return "signpost.right"
        case "receipt": return "doc.text"
        case "document": return "doc"
        case "ticket": return "ticket"
        default: return "photo"
        }
    }

    private func sceneLabel(_ type: String) -> String {
        switch type {
        case "menu": return "菜单"
        case "sign": return "路牌 / 告示"
        case "receipt": return "小票"
        case "document": return "文档"
        case "ticket": return "票据"
        default: return "图片说明"
        }
    }
}
