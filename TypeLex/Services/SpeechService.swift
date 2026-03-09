import AVFoundation
import OSLog

@MainActor
final class SpeechService: SpeechPlaying {
    static let shared = SpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    
    private init() {}
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let player = player, player.isPlaying {
            player.stop()
        }
    }
    
    func speak(_ text: String, language: String = "en-US") {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        synthesizer.speak(utterance)
    }
    
    func playAudio(at url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            AppLogger.speech.error("Failed to play audio at \(url.path, privacy: .public): \(error.localizedDescription)")
        }
    }
}
