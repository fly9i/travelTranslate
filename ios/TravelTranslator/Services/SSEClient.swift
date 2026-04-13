import Foundation

/// 一条已解析好的 SSE 事件。
struct SSEEvent {
    let event: String
    let data: String
}

/// 最小 SSE 客户端：基于 URLSession `bytes(for:)`，按行解析 `event:` / `data:` 帧。
/// 事件以空行（`\n\n`）结束，支持跨多行的 data 字段拼接。
enum SSEClient {
    /// 对任意 URLRequest（通常 POST）发起 SSE 流请求，产生事件序列。
    static func stream(request: URLRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = request
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse,
                       !(200..<300).contains(http.statusCode) {
                        throw APIError.http(http.statusCode, "SSE 连接失败")
                    }

                    var currentEvent = "message"
                    var dataLines: [String] = []

                    for try await line in bytes.lines {
                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let payload = dataLines.joined(separator: "\n")
                                continuation.yield(SSEEvent(event: currentEvent, data: payload))
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
                    // 收尾：可能最后一个事件没有空行结束
                    if !dataLines.isEmpty {
                        let payload = dataLines.joined(separator: "\n")
                        continuation.yield(SSEEvent(event: currentEvent, data: payload))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
