import SwiftUI
import UIKit

/// 历史页：自动收录所有文本翻译 + 拍照翻译，每条都是"已收藏"状态；
/// 点亮着的星号 = 取消 = 从历史删除。
struct HistoryView: View {
    @StateObject private var store = HistoryStore.shared

    var body: some View {
        Group {
            if store.entries.isEmpty {
                ContentUnavailableView(
                    "还没有历史",
                    systemImage: "clock",
                    description: Text("做过的翻译会自动出现在这里。点亮着的星号即可删除。")
                )
            } else {
                List {
                    ForEach(store.entries) { entry in
                        HistoryRow(entry: entry, store: store)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            store.remove(store.entries[i])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("历史")
    }
}

/// 单条历史：文本翻译横向布局，拍照翻译左缩略图 + 右摘要，可点进详情页。
private struct HistoryRow: View {
    let entry: HistoryEntry
    @ObservedObject var store: HistoryStore

    var body: some View {
        Group {
            if entry.kind == .vision, let snapshot = store.snapshot(for: entry) {
                NavigationLink {
                    CameraOCRView(snapshot: snapshot)
                } label: {
                    visionContent(snapshot: snapshot)
                }
                .buttonStyle(.plain)
            } else if let text = entry.text {
                textContent(text: text)
            }
        }
    }

    private func visionContent(snapshot: OCRSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: snapshot.composedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.summary?.isEmpty == false ? snapshot.summary! : "拍照翻译")
                    .font(.subheadline)
                    .lineLimit(2)
                Text("\(snapshot.items.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            starButton
        }
    }

    private func textContent(text: HistoryTextEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(text.sourceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(text.translatedText)
                    .font(.body)
                    .lineLimit(3)
                if let note = text.culturalNote, !note.isEmpty {
                    Label(note, systemImage: "lightbulb")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            starButton
        }
    }

    private var starButton: some View {
        Button {
            store.remove(entry)
        } label: {
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

enum HistoryEntryKind: String, Codable {
    case text
    case vision
}

struct HistoryTextEntry: Codable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let culturalNote: String?
}

struct HistoryVisionItem: Codable {
    let sourceText: String
    let translatedText: String
    let note: String?
    // bbox 以四个 Double 存，Vision 归一化坐标（左下原点）
    let bx: Double
    let by: Double
    let bw: Double
    let bh: Double
}

struct HistoryVisionEntry: Codable {
    let imageFilename: String
    let items: [HistoryVisionItem]
    let sceneType: String?
    let summary: String?
}

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let kind: HistoryEntryKind
    let text: HistoryTextEntry?
    let vision: HistoryVisionEntry?
}

// MARK: - Store

/// 全局历史存储：元数据走 UserDefaults（JSON 编码），图片落到 Documents/history/。
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let key = "history.v1"
    private let dirURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dirURL = docs.appendingPathComponent("history", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        load()
    }

    func addText(
        source: String,
        translated: String,
        sourceLanguage: String,
        targetLanguage: String,
        culturalNote: String?
    ) {
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            kind: .text,
            text: HistoryTextEntry(
                sourceText: source,
                translatedText: translated,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                culturalNote: culturalNote
            ),
            vision: nil
        )
        entries.insert(entry, at: 0)
        save()
    }

    func addVision(
        image: UIImage,
        items: [ResolvedTranslateItem],
        sceneType: String?,
        summary: String?
    ) {
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        let fileURL = dirURL.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            NSLog("[History] failed to encode vision image")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[History] failed to write image: \(error)")
            return
        }
        let visionItems = items.map { item in
            HistoryVisionItem(
                sourceText: item.sourceText,
                translatedText: item.translatedText,
                note: item.note,
                bx: Double(item.boundingBox.minX),
                by: Double(item.boundingBox.minY),
                bw: Double(item.boundingBox.width),
                bh: Double(item.boundingBox.height)
            )
        }
        let entry = HistoryEntry(
            id: id,
            createdAt: Date(),
            kind: .vision,
            text: nil,
            vision: HistoryVisionEntry(
                imageFilename: filename,
                items: visionItems,
                sceneType: sceneType,
                summary: summary
            )
        )
        entries.insert(entry, at: 0)
        save()
    }

    func remove(_ entry: HistoryEntry) {
        if let v = entry.vision {
            let url = dirURL.appendingPathComponent(v.imageFilename)
            try? FileManager.default.removeItem(at: url)
        }
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// 从历史条目重建一个 OCRSnapshot，供 CameraOCRView 复用。
    func snapshot(for entry: HistoryEntry) -> OCRSnapshot? {
        guard let v = entry.vision else { return nil }
        let url = dirURL.appendingPathComponent(v.imageFilename)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let resolved = v.items.map { item in
            ResolvedTranslateItem(
                sourceText: item.sourceText,
                translatedText: item.translatedText,
                note: item.note,
                boundingBox: CGRect(x: item.bx, y: item.by, width: item.bw, height: item.bh)
            )
        }
        return OCRSnapshot(
            originalImage: image,
            composedImage: image,
            rawBlocks: [],
            items: resolved,
            sceneType: v.sceneType,
            summary: v.summary
        )
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
