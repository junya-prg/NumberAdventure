import Foundation
import CoreHaptics
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    
    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            engine?.stoppedHandler = { reason in
                print("Haptic Engine stopped: \(reason)")
            }
            engine?.resetHandler = { [weak self] in
                print("Haptic Engine reset")
                try? self?.engine?.start()
            }
        } catch {
            print("Failed to start Haptic Engine: \(error.localizedDescription)")
        }
    }
    
    /// 正解時の「ファンファーレ触覚」: ポン・ポン・ポン・パン！と軽快に弾けるリズム
    func playCorrectHaptic() {
        guard let engine = engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        
        do {
            let events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75)
                ], relativeTime: 0.0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                ], relativeTime: 0.08),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0.18),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0.18, duration: 0.2)
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            print("Failed to play correct haptic: \(error)")
        }
    }
    
    /// 不正解時の「ブッブー触覚」: 低めで強めの振動を2回（ブー・ブー）と重く響かせる
    func playIncorrectHaptic() {
        guard let engine = engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        do {
            // シャープネスを0.25と低く設定し、ドラムのバスドラムのような重低音的なブブッという触感を表現
            let events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                ], relativeTime: 0.0, duration: 0.18),
                
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                ], relativeTime: 0.28, duration: 0.25)
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            print("Failed to play incorrect haptic: \(error)")
        }
    }
}
