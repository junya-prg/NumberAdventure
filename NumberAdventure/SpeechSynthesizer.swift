import Foundation
import AVFoundation
import Combine

class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking: Bool = false
    
    private static let sharedSynthesizer = AVSpeechSynthesizer()
    private static var activeDelegate: SpeechSynthesizer? = nil
    
    override init() {
        super.init()
        Self.sharedSynthesizer.delegate = self
        Self.activeDelegate = self
    }
    
    func speak(_ text: String) {
        Self.sharedSynthesizer.delegate = self
        Self.activeDelegate = self
        
        if Self.sharedSynthesizer.isSpeaking {
            Self.sharedSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 利用可能な日本語(ja-JP)の音声を取得し、最も高品質なものを選択
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let japaneseVoices = voices.filter { $0.language == "ja-JP" }
        
        var selectedVoice = AVSpeechSynthesisVoice(language: "ja-JP")
        
        if let premiumVoice = japaneseVoices.first(where: { $0.quality == .premium }) {
            selectedVoice = premiumVoice
        } else if let enhancedVoice = japaneseVoices.first(where: { $0.quality == .enhanced }) {
            selectedVoice = enhancedVoice
        } else if let siriVoice = japaneseVoices.first(where: { $0.identifier.contains("siri") }) {
            selectedVoice = siriVoice
        }
        
        utterance.voice = selectedVoice
        
        // 高品質の音声は元から自然なため、ピッチ調整は最小限にし、通常音声の場合は子供向けに少し高め・ゆっくりにする
        if let voice = selectedVoice, voice.quality == .premium || voice.quality == .enhanced {
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.90
            utterance.pitchMultiplier = 1.05
        } else {
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
            utterance.pitchMultiplier = 1.15
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.ambient, mode: .default, options: .mixWithOthers)
        try? audioSession.setActive(true)
        
        Self.sharedSynthesizer.speak(utterance)
    }
    
    func stop() {
        if Self.sharedSynthesizer.isSpeaking {
            Self.sharedSynthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            Self.activeDelegate?.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            Self.activeDelegate?.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            Self.activeDelegate?.isSpeaking = false
        }
    }
}
