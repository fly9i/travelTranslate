import AVFoundation
import Speech
import os

/// 按住说话语音识别服务（类似微信发语音）。
///
/// 使用方式：start() 开始录音并实时识别 → stop() 结束并拿到最终文本。
/// 单个 session 受 iOS 限制约 1 分钟。
@MainActor
final class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()

    @Published private(set) var isRecording = false
    @Published private(set) var partialText: String = ""
    @Published var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.traveltranslator.app", category: "SpeechRecognition")

    private init() {}

    /// 请求麦克风 + 语音识别权限。第一次调用会弹系统弹窗。
    func requestAuthorization() async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            errorMessage = "未获得语音识别权限"
            return false
        }
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        if !micGranted {
            errorMessage = "未获得麦克风权限"
        }
        return micGranted
    }

    /// 开始录音 + 识别。languageCode 用中文 zh-CN（用户说中文翻给对方）或目标语言。
    func start(languageCode: String) throws {
        guard !isRecording else { return }
        errorMessage = nil
        partialText = ""

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)),
              recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognition", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "当前语种(\(languageCode))语音识别不可用"
            ])
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.partialText = result.bestTranscription.formattedString
                }
                if let error {
                    self.logger.error("识别错误: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// 结束录音，返回识别到的最终文本。
    @discardableResult
    func stop() -> String {
        guard isRecording else { return partialText }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRecording = false
        return partialText
    }

    /// 用户取消录音（不返回文本）。
    func cancel() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        partialText = ""
    }
}
