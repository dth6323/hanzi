import AVFoundation

final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        synth.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
    }
    
    func speak(_ text: String, slow: Bool = false) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return }
        
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = slow ? 0.25 : 0.48
        utterance.pitchMultiplier = 1.0
        
        synth.speak(utterance)
    }
}
