import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var correctPlayer: AVAudioPlayer?
    private var incorrectPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
        preloadSounds()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // 他の音声（BGMやSpeechSynthesizerの読み上げ音声）とミックスできるようにカテゴリを設定
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category for SoundManager: \(error)")
        }
    }
    
    private func preloadSounds() {
        // 正解音のWAVデータを生成してプリロード
        let correctData = generateCorrectSoundData()
        do {
            correctPlayer = try AVAudioPlayer(data: correctData)
            correctPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize correct audio player: \(error)")
        }
        
        // 不正解音のWAVデータを生成してプリロード
        let incorrectData = generateIncorrectSoundData()
        do {
            incorrectPlayer = try AVAudioPlayer(data: incorrectData)
            incorrectPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize incorrect audio player: \(error)")
        }
    }
    
    /// 正解時の効果音を再生 (C5 -> E5 -> C6 と軽快に駆け上がる三角波)
    /// HapticManager.shared.playCorrectHaptic() のタイミング（0.0s, 0.08s, 0.18s）と完全に同期
    func playCorrect() {
        // 録音等でカテゴリが変わっている可能性があるため、再生前に.ambientに再設定してスピーカーから出力する
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        
        if let player = correctPlayer {
            if player.isPlaying {
                player.stop()
            }
            player.currentTime = 0
            player.play()
        }
    }
    
    /// 不正解時の効果音を再生 (ブブーと2回鳴る低い矩形波の不協和音)
    /// HapticManager.shared.playIncorrectHaptic() のタイミング（0.0s~0.18s, 0.28s~0.53s）と完全に同期
    func playIncorrect() {
        // 録音等でカテゴリが変わっている可能性があるため、再生前に.ambientに再設定してスピーカーから出力する
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        
        if let player = incorrectPlayer {
            if player.isPlaying {
                player.stop()
            }
            player.currentTime = 0
            player.play()
        }
    }
    
    // MARK: - WAV Binary Generation
    
    /// WAVファイルの共通ヘッダーを生成
    private func createWavHeader(dataSize: Int, sampleRate: Int = 44100, numChannels: Int = 1, bitsPerSample: Int = 16) -> Data {
        var header = Data()
        
        // RIFF
        header.append(contentsOf: "RIFF".utf8)
        
        // 総ファイルサイズ - 8
        let totalFileSize = Int32(dataSize + 36)
        withUnsafeBytes(of: totalFileSize.littleEndian) { header.append(contentsOf: $0) }
        
        // WAVE
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt 
        header.append(contentsOf: "fmt ".utf8)
        
        // 構造体のサイズ (16)
        let fmtSize = Int32(16)
        withUnsafeBytes(of: fmtSize.littleEndian) { header.append(contentsOf: $0) }
        
        // フォーマットID (1 = PCM)
        let formatType = Int16(1)
        withUnsafeBytes(of: formatType.littleEndian) { header.append(contentsOf: $0) }
        
        // チャンネル数
        let channels = Int16(numChannels)
        withUnsafeBytes(of: channels.littleEndian) { header.append(contentsOf: $0) }
        
        // サンプリングレート
        let rate = Int32(sampleRate)
        withUnsafeBytes(of: rate.littleEndian) { header.append(contentsOf: $0) }
        
        // バイトレート = sampleRate * numChannels * bitsPerSample / 8
        let byteRate = Int32(sampleRate * numChannels * (bitsPerSample / 8))
        withUnsafeBytes(of: byteRate.littleEndian) { header.append(contentsOf: $0) }
        
        // ブロック境界 = numChannels * bitsPerSample / 8
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        withUnsafeBytes(of: blockAlign.littleEndian) { header.append(contentsOf: $0) }
        
        // サンプルあたりのビット数
        let bits = Int16(bitsPerSample)
        withUnsafeBytes(of: bits.littleEndian) { header.append(contentsOf: $0) }
        
        // data
        header.append(contentsOf: "data".utf8)
        
        // データサイズ
        let dSize = Int32(dataSize)
        withUnsafeBytes(of: dSize.littleEndian) { header.append(contentsOf: $0) }
        
        return header
    }
    
    /// 正解音 (三角波によるきらきらアルペジオ) の波形データを生成
    private func generateCorrectSoundData() -> Data {
        let sampleRate = 44100
        let duration = 0.45 // 全体で0.45秒
        let totalSamples = Int(Double(sampleRate) * duration)
        
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)
        
        // 音符の定義 (時間範囲と周波数)
        // 1音目: 0.0s ~ 0.08s -> C5 (523.25 Hz)
        // 2音目: 0.08s ~ 0.18s -> E5 (659.25 Hz)
        // 3音目: 0.18s ~ 0.45s -> C6 (1046.50 Hz)
        let note1End = Int(Double(sampleRate) * 0.08)
        let note2End = Int(Double(sampleRate) * 0.18)
        
        let freq1 = 523.25
        let freq2 = 659.25
        let freq3 = 1046.50
        
        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            let freq: Double
            let noteTime: Double // 各音符の開始時からの経過時間
            let noteDuration: Double // 各音符の長さ
            
            if i < note1End {
                freq = freq1
                noteTime = t
                noteDuration = 0.08
            } else if i < note2End {
                freq = freq2
                noteTime = t - 0.08
                noteDuration = 0.10
            } else {
                freq = freq3
                noteTime = t - 0.18
                noteDuration = 0.27
            }
            
            // 三角波の生成
            let angle = 2.0 * Double.pi * freq * t
            let sinValue = sin(angle)
            let triangleValue = 2.0 / Double.pi * asin(sinValue)
            
            // 音符の切り替わり時にクリックノイズが発生しないよう、各音符の終わりに短いフェードアウトをかける
            var envelope = 1.0
            let fadeOutTime = 0.015 // 15ms フェードアウト
            
            if i < note1End {
                let timeRemaining = noteDuration - noteTime
                if timeRemaining < fadeOutTime {
                    envelope = timeRemaining / fadeOutTime
                }
            } else if i < note2End {
                let timeRemaining = noteDuration - noteTime
                if timeRemaining < fadeOutTime {
                    envelope = timeRemaining / fadeOutTime
                }
            } else {
                // 最後の音は長めの減衰（指数関数フェード）
                // 指数的に減衰させることで、余韻を残して綺麗に消える
                envelope = exp(-5.0 * noteTime)
            }
            
            let maxAmplitude: Double = 27000.0 // 音量
            let sample = Int16(triangleValue * maxAmplitude * envelope)
            samples.append(sample)
        }
        
        var audioData = Data()
        samples.withUnsafeBufferPointer { buffer in
            audioData.append(UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count))
        }
        
        let header = createWavHeader(dataSize: audioData.count)
        return header + audioData
    }
    
    /// 不正解音 (矩形波をミックスした低い不協和音を2回) の波形データを生成
    private func generateIncorrectSoundData() -> Data {
        let sampleRate = 44100
        let duration = 0.55 // 全体で0.55秒
        let totalSamples = Int(Double(sampleRate) * duration)
        
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)
        
        // 音1: 0.0s ~ 0.18s
        // 無音: 0.18s ~ 0.28s
        // 音2: 0.28s ~ 0.53s
        let sound1End = Int(Double(sampleRate) * 0.18)
        let silenceEnd = Int(Double(sampleRate) * 0.28)
        let sound2End = Int(Double(sampleRate) * 0.53)
        
        // 低い不協和音（C3付近の130Hzと137Hzを混ぜる）
        let freqA = 130.0
        let freqB = 137.0
        
        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            
            if i >= sound1End && i < silenceEnd {
                // 無音区間
                samples.append(0)
                continue
            }
            
            if i >= sound2End {
                // 最後の余韻カット
                samples.append(0)
                continue
            }
            
            // 矩形波の生成
            let waveA = sin(2.0 * Double.pi * freqA * t) >= 0 ? 1.0 : -1.0
            let waveB = sin(2.0 * Double.pi * freqB * t) >= 0 ? 1.0 : -1.0
            let mixedWave = (waveA + waveB) * 0.5
            
            var envelope = 1.0
            if i < sound1End {
                // 音符1のエンベロープ: 最初はアタック強く、終わりは15msでフェードアウト
                let noteTime = t
                let noteDuration = 0.18
                let timeRemaining = noteDuration - noteTime
                let fadeOutTime = 0.015
                if timeRemaining < fadeOutTime {
                    envelope = timeRemaining / fadeOutTime
                }
            } else if i >= silenceEnd && i < sound2End {
                // 音符2のエンベロープ: 開始は10msでフェードイン、終わりは30msでフェードアウト
                let noteTime = t - 0.28
                let noteDuration = 0.25
                let timeRemaining = noteDuration - noteTime
                let fadeInTime = 0.010
                let fadeOutTime = 0.030
                
                if noteTime < fadeInTime {
                    envelope = noteTime / fadeInTime
                } else if timeRemaining < fadeOutTime {
                    envelope = timeRemaining / fadeOutTime
                }
            }
            
            let maxAmplitude: Double = 6000.0 // 音量
            let sample = Int16(mixedWave * maxAmplitude * envelope)
            samples.append(sample)
        }
        
        var audioData = Data()
        samples.withUnsafeBufferPointer { buffer in
            audioData.append(UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count))
        }
        
        let header = createWavHeader(dataSize: audioData.count)
        return header + audioData
    }
}
