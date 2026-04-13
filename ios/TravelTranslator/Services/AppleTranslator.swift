import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// 描述一次 OCR 批量翻译请求。由 ViewModel 发布，View 层的
/// `AppleBatchTranslateHost` 监听到后调用系统 Translation framework 执行。
struct PendingBatchRequest: Identifiable, Equatable {
    let id: UUID
    let texts: [String]
    /// 源语言 BCP-47，nil 表示让系统自动识别
    let sourceLang: String?
    /// 目标语言 BCP-47
    let targetLang: String
}

/// 苹果本地翻译可用性判断：Translation framework 需要 iOS 17.4+。
enum AppleTranslator {
    static var isAvailable: Bool {
        if #available(iOS 17.4, *) {
            return true
        }
        return false
    }
}

#if canImport(Translation)

/// 宿主视图：接一个 `PendingBatchRequest`，在系统 TranslationSession 里批量翻译，
/// 结果通过 `onComplete(id, result)` 回调给 ViewModel。
///
/// 结果为 nil 表示本地翻译不可用或失败，调用方应回退到后端。
@available(iOS 17.4, *)
struct AppleBatchTranslateHost: View {
    let request: PendingBatchRequest?
    let onComplete: (UUID, [String]?) -> Void

    @State private var configuration: TranslationSession.Configuration?
    @State private var activeRequestID: UUID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(configuration) { session in
                guard let req = request, activeRequestID == req.id else { return }
                let result = await Self.runBatch(session: session, texts: req.texts)
                await MainActor.run {
                    onComplete(req.id, result)
                    configuration = nil
                    activeRequestID = nil
                }
            }
            .onChange(of: request) { _, new in
                guard let new else {
                    configuration = nil
                    activeRequestID = nil
                    return
                }
                activeRequestID = new.id
                configuration = TranslationSession.Configuration(
                    source: new.sourceLang.map { Locale.Language(identifier: $0) },
                    target: Locale.Language(identifier: new.targetLang)
                )
            }
    }

    private static func runBatch(
        session: TranslationSession,
        texts: [String]
    ) async -> [String]? {
        var out = texts
        do {
            let requests = texts.enumerated().map { idx, text in
                TranslationSession.Request(
                    sourceText: text,
                    clientIdentifier: String(idx)
                )
            }
            let responses = try await session.translations(from: requests)
            for response in responses {
                if let cid = response.clientIdentifier, let idx = Int(cid),
                   idx >= 0, idx < out.count {
                    out[idx] = response.targetText
                }
            }
            return out
        } catch {
            return nil
        }
    }
}

#endif
