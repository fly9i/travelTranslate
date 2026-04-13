import Foundation

/// 一条已解析好的 SSE 事件。
struct SSEEvent {
    let event: String
    let data: String
}

/// 基于 URLSessionDataDelegate 的 SSE 客户端。
///
/// 为什么不用 URLSession.bytes(for:)：在部分 iOS 版本 + 小块响应下，
/// `bytes(for:)` 会缓存一段时间才吐数据，对 SSE 这种低速、事件驱动的流不可靠。
/// 用 Delegate 收到的 `didReceive data:` 会立刻触发，更接近真正的"push"。
final class SSEClient: NSObject {
    private var continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation?
    private var buffer = Data()
    private var currentEvent = "message"
    private var dataLines: [String] = []
    private var task: URLSessionDataTask?
    private var session: URLSession?

    /// 发起一个 SSE 请求，返回解析后的事件流。
    static func stream(request: URLRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let client = SSEClient()
            client.continuation = continuation
            client.start(request: request)
            continuation.onTermination = { @Sendable _ in
                client.cancel()
            }
        }
    }

    private func start(request: URLRequest) {
        var req = request
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = req.timeoutInterval > 0 ? req.timeoutInterval : 120
        config.timeoutIntervalForResource = 600
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        config.waitsForConnectivity = false

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.dataTask(with: req)
        self.task = task
        NSLog("[SSE] start %@ body=%ld", req.url?.absoluteString ?? "?", req.httpBody?.count ?? -1)
        task.resume()
    }

    private func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
        task = nil
        session = nil
    }

    /// 把收到的字节追加到 buffer，并按 `\n` 切行解析 SSE 协议。
    private func processBuffer() {
        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0..<newlineRange.upperBound)
            let rawLine = String(data: lineData, encoding: .utf8) ?? ""
            // 去掉可能的 \r
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

            if line.isEmpty {
                if !dataLines.isEmpty {
                    let payload = dataLines.joined(separator: "\n")
                    let event = SSEEvent(event: currentEvent, data: payload)
                    NSLog("[SSE] event=%@ data.len=%ld", event.event, payload.count)
                    continuation?.yield(event)
                }
                currentEvent = "message"
                dataLines.removeAll(keepingCapacity: true)
                continue
            }
            if line.hasPrefix(":") { continue }  // 心跳/注释
            if line.hasPrefix("event:") {
                currentEvent = String(line.dropFirst(6))
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(
                    String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                )
            }
        }
    }
}

extension SSEClient: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse {
            NSLog("[SSE] response status=%ld", http.statusCode)
            if !(200..<300).contains(http.statusCode) {
                continuation?.finish(throwing: APIError.http(http.statusCode, "SSE 连接失败"))
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        NSLog("[SSE] chunk bytes=%ld", data.count)
        buffer.append(data)
        processBuffer()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // 收尾：如果最后一个事件没有空行结束，补发一次
        if !dataLines.isEmpty {
            let payload = dataLines.joined(separator: "\n")
            NSLog("[SSE] trailing event=%@ data.len=%ld", currentEvent, payload.count)
            continuation?.yield(SSEEvent(event: currentEvent, data: payload))
            dataLines.removeAll()
        }
        if let error {
            NSLog("[SSE] completed with error: %@", error.localizedDescription)
            continuation?.finish(throwing: error)
        } else {
            NSLog("[SSE] completed ok")
            continuation?.finish()
        }
        self.session?.finishTasksAndInvalidate()
    }
}
