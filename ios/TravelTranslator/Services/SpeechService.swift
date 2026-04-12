import AVFoundation

/// 语音合成（TTS）服务，使用系统 AVSpeechSynthesizer。
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    /// 朗读目标文本。languageCode 示例：ja-JP / ko-KR / en-US。
    func speak(_ text: String, languageCode: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
