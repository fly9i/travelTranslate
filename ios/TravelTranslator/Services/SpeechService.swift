import AVFoundation
import os

/// 语音合成（TTS）服务，使用系统 AVSpeechSynthesizer。
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "com.traveltranslator.app", category: "SpeechService")

    private init() {
        configureAudioSession()
    }

    // 切到 .playback 通道，保证静音开关拨到静音也能出声、
    // 并在朗读时压低其他 App 的声音（duckOthers）。
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            logger.error("配置 AVAudioSession 失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 朗读目标文本。languageCode 示例：ja-JP / ko-KR / en-US。
    func speak(_ text: String, languageCode: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolveVoice(for: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // 系统里若没装指定语种的 voice，AVSpeechSynthesisVoice(language:) 可能返回 nil
    // 导致静默失败；fallback 到首个以 prefix 匹配的 voice，再退到系统默认。
    private func resolveVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            return voice
        }
        let prefix = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
        if let fallback = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix(prefix)
        }) {
            logger.warning("未找到 \(languageCode, privacy: .public) voice，fallback 到 \(fallback.language, privacy: .public)")
            return fallback
        }
        logger.warning("未找到 \(languageCode, privacy: .public) voice，使用系统默认")
        return nil
    }
}
