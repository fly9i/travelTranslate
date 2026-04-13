import SwiftUI

/// 拍照 / 相册 翻译结果详情页。从首页 NavigationLink 过来。
struct CameraOCRView: View {
    let snapshot: OCRSnapshot
    @State private var showPreview = false

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // 顶部固定图片：高度上限为可用高度的 40%，滚动译文时保持可见
                // 点击进入全屏预览（支持双指缩放 / 双击放大 / 拖动）
                Image(uiImage: snapshot.composedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: proxy.size.height * 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding([.horizontal, .top])
                    .contentShape(Rectangle())
                    .onTapGesture { showPreview = true }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let scene = snapshot.sceneType,
                           let summary = snapshot.summary,
                           !summary.isEmpty {
                            SceneSummaryCard(sceneType: scene, summary: summary)
                        }

                        if !snapshot.items.isEmpty {
                            Text("原文 / 译文对照（\(snapshot.items.count) 项）")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(snapshot.items.enumerated()), id: \.element.id) { idx, item in
                                    TranslateItemRow(index: idx, item: item)
                                }
                            }
                        } else {
                            Text("等待 LLM 返回结果…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
        }
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPreview) {
            ImagePreviewView(image: snapshot.composedImage) {
                showPreview = false
            }
        }
    }
}

/// 全屏图片预览：支持双指捏合缩放、双击放大 / 还原、拖动平移。
struct ImagePreviewView: View {
    let image: UIImage
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= minScale {
                                    withAnimation(.spring()) {
                                        scale = minScale
                                        lastScale = minScale
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                guard scale > minScale else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > minScale {
                            scale = minScale
                            lastScale = minScale
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }
}

/// 一个翻译项目的展示行：左侧彩色编号徽章，右侧原文 / 译文 / 可选提醒。
struct TranslateItemRow: View {
    let index: Int
    let item: ResolvedTranslateItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NumberBadge(number: index + 1, color: OCRBlockPalette.color(at: index))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.sourceText)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(item.translatedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let note = item.note, !note.isEmpty {
                    Label(note, systemImage: "lightbulb")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 编号徽章：和标注图上的圆点同色。
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

/// LLM 判断出的场景简介。
struct SceneSummaryCard: View {
    let sceneType: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: sceneIcon(sceneType))
                Text(sceneLabel(sceneType)).font(.headline)
                Spacer()
            }
            Text(summary).font(.callout)
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
