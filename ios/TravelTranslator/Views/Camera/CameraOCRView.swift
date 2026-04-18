import SwiftUI
import UIKit

/// 拍照 / 相册 翻译结果详情页。
///
/// 支持两种入口：
/// - 从首页拍照 / 相册选图：`init(initialImage:)` 进入后立即启动本地 OCR + 流式视觉翻译，
///   流过程中逐步填充 `viewModel.snapshot`，页面随之刷新。
/// - 从历史记录回放：`init(snapshot:)` 直接展示完整快照。
struct CameraOCRView: View {
    @StateObject private var viewModel: CameraOCRViewModel
    @EnvironmentObject private var appState: AppState
    @State private var showPreview = false
    @State private var shareItem: ShareItem?

    init(initialImage: UIImage) {
        _viewModel = StateObject(wrappedValue: CameraOCRViewModel(initialImage: initialImage))
    }

    init(snapshot: OCRSnapshot) {
        _viewModel = StateObject(wrappedValue: CameraOCRViewModel(snapshot: snapshot))
    }

    private var snapshot: OCRSnapshot { viewModel.snapshot }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // 顶部固定图片：占可用高度 40%，点击进入全屏预览
                Image(uiImage: snapshot.composedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: proxy.size.height * 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.FG.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .designShadow(Theme.Shadow.soft)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { showPreview = true }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let err = viewModel.ocrError {
                            Label(err, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.Semantic.danger)
                                )
                        } else if viewModel.isStreaming {
                            streamingBanner
                        }

                        if let scene = snapshot.sceneType,
                           let summary = snapshot.summary,
                           !summary.isEmpty {
                            SceneSummaryCard(sceneType: scene, summary: summary)
                        }

                        if !snapshot.items.isEmpty {
                            HStack(alignment: .firstTextBaseline) {
                                Text("对照译文")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.FG.primary)
                                Spacer()
                                Text("\(snapshot.items.count) 项")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.FG.tertiary)
                            }

                            LazyVStack(spacing: 8) {
                                ForEach(Array(snapshot.items.enumerated()), id: \.element.id) { idx, item in
                                    TranslateItemRow(index: idx, item: item)
                                }
                            }
                        } else if !viewModel.isStreaming && viewModel.ocrError == nil {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("等待 LLM 返回结果…")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.FG.tertiary)
                            }
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
            }
            .background(Theme.BG.base.ignoresSafeArea())
        }
        .navigationTitle("拍照翻译")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let img = PosterRenderer.render(snapshot: snapshot) {
                        shareItem = ShareItem(image: img)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享")
                .disabled(viewModel.isStreaming || snapshot.items.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            ImagePreviewView(snapshot: snapshot) {
                showPreview = false
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
        .task {
            viewModel.startIfNeeded(appState: appState)
        }
    }

    /// 顶部流式状态条：最近一行日志 + 进度指示。
    private var streamingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Theme.Accent.deep)
                .scaleEffect(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 正在识别并翻译…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Accent.deep)
                if let line = viewModel.streamLog.last, !line.isEmpty {
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.FG.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Accent.soft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Accent.base.opacity(0.15), lineWidth: 0.5)
        )
    }
}

/// 给 sheet(item:) 用的包装，使 UIImage 可作为 Identifiable。
private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// UIActivityViewController 的 SwiftUI 包装。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 把 OCRSnapshot 渲染成一张长图用于分享。
enum PosterRenderer {
    @MainActor
    static func render(snapshot: OCRSnapshot) -> UIImage? {
        let view = SharePosterView(snapshot: snapshot)
            .frame(width: 800)
            .background(Color(.systemBackground))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

struct SharePosterView: View {
    let snapshot: OCRSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(uiImage: snapshot.composedImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if let scene = snapshot.sceneType,
               let summary = snapshot.summary,
               !summary.isEmpty {
                SceneSummaryCard(sceneType: scene, summary: summary)
            }

            if !snapshot.items.isEmpty {
                Text("原文 / 译文对照（\(snapshot.items.count) 项）")
                    .font(.title3.bold())
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(snapshot.items.enumerated()), id: \.element.id) { idx, item in
                        TranslateItemRow(index: idx, item: item)
                    }
                }
            }

            HStack {
                Spacer()
                Text("TravelTranslator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

/// 全屏图片预览：支持双指捏合缩放、双击放大 / 还原、拖动平移。
struct ImagePreviewView: View {
    let snapshot: OCRSnapshot
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var shareItem: ShareItem?

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: snapshot.composedImage)
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
                HStack(spacing: 16) {
                    Spacer()
                    Button {
                        shareItem = ShareItem(image: snapshot.composedImage)
                    } label: {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .accessibilityLabel("分享")

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .accessibilityLabel("关闭")
                }
                .padding()
                Spacer()
            }
        }
        .statusBarHidden()
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }
}

/// 翻译项行：左侧彩色编号徽章 + 原文 / 译文 + 文化提示胶囊 + 朗读按钮。
struct TranslateItemRow: View {
    let index: Int
    let item: ResolvedTranslateItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NumberBadge(number: index + 1, color: OCRBlockPalette.color(at: index))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.sourceText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.FG.primary)
                Text(item.translatedText)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.FG.secondary)
                if let note = item.note, !note.isEmpty {
                    Label(note, systemImage: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Chip.vanilla.fg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.Chip.vanilla.bg)
                        )
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                SpeechService.shared.speak(item.sourceText, languageCode: "ja-JP")
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.FG.primary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(Theme.FG.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.BG.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
        )
    }
}

/// 场景总结卡片：珊瑚橙柔底 + 场景图标 + AI 总结正文。
struct SceneSummaryCard: View {
    let sceneType: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(sceneEmoji(sceneType))
                    .font(.system(size: 20))
                Text(sceneLabel(sceneType))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Accent.deep)
                Spacer()
                Text("AI 总结")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Accent.deep.opacity(0.7))
            }
            Text(summary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.FG.primary)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Accent.soft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Accent.base.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func sceneEmoji(_ type: String) -> String {
        switch type {
        case "menu": return "🍜"
        case "sign": return "🪧"
        case "receipt": return "🧾"
        case "document": return "📄"
        case "ticket": return "🎫"
        default: return "📷"
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
