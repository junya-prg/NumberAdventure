import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notAuthorizedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "音声認識の準備ができませんでした。"
            case .notAuthorizedToRecognize: return "音声認識の使用が許可されていません。"
            case .notAuthorizedToRecord: return "マイクの使用が許可されていません。"
            case .recognizerIsUnavailable: return "音声認識サービスは現在利用できません。"
            }
        }
    }
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
        
        #if !targetEnvironment(simulator)
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasAuthorizationToRecord() else {
                    throw RecognizerError.notAuthorizedToRecord
                }
            } catch {
                if let recognizerError = error as? RecognizerError {
                    self.reportError(recognizerError)
                } else {
                    self.reportError(error)
                }
            }
        }
        #endif
    }
    
    deinit {
        reset()
    }
    
    func startTranscribing() {
        Task { @MainActor in
            self.reset()
            self.errorMessage = nil
            self.transcript = ""
            
            do {
                guard let recognizer = recognizer, recognizer.isAvailable else {
                    throw RecognizerError.recognizerIsUnavailable
                }
                
                let audioEngine = AVAudioEngine()
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                
                if recognizer.supportsOnDeviceRecognition {
                    request.requiresOnDeviceRecognition = true
                }
                
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    request.append(buffer)
                }
                
                audioEngine.prepare()
                try audioEngine.start()
                
                self.audioEngine = audioEngine
                self.request = request
                
                self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if let result = result {
                        Task { @MainActor in
                            self.transcript = result.bestTranscription.formattedString
                        }
                    }
                    
                    if error != nil {
                        self.stopTranscribing()
                    }
                }
                
                self.isRecording = true
            } catch {
                self.reportError(error)
                self.stopTranscribing()
            }
        }
    }
    
    func stopTranscribing() {
        Task { @MainActor in
            reset()
            self.isRecording = false
        }
    }
    
    func reset() {
        task?.cancel()
        task = nil
        request = nil
        
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func reportError(_ error: Error) {
        Task { @MainActor in
            if let recognizerError = error as? RecognizerError {
                self.errorMessage = recognizerError.message
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasAuthorizationToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
