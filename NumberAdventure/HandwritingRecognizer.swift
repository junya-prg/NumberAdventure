import Foundation
import UIKit
import PencilKit
import Vision

class HandwritingRecognizer {
    /// PKDrawing から手書き数字 (0-9) を認識します
    /// - Parameters:
    ///   - drawing: 認識対象の PKDrawing
    ///   - bounds: 描画エリアの全体領域
    ///   - expected: このスロットで期待される正解の数字 (e.g. "3")
    /// - Returns: 認識された数字、または期待値と合致する場合は期待値
    static func recognizeDigit(from drawing: PKDrawing, in bounds: CGRect, expected: String) async -> String {
        print("[HR] ストローク数: \(drawing.strokes.count)")
        print("[HR] drawing.bounds: \(drawing.bounds)")
        
        guard !drawing.strokes.isEmpty else {
            print("[HR] ストロークが空のため終了")
            return ""
        }
        
        // 1. 十分なパディングで正方形にフレーミング（文字が画像の端に接触して認識エラーになるのを防ぐ）
        let drawingBounds = drawing.bounds
        let maxSide = max(drawingBounds.width, drawingBounds.height)
        let centerX = drawingBounds.midX
        let centerY = drawingBounds.midY
        let paddedSide = max(maxSide * 1.35, 60.0)
        let squareBounds = CGRect(
            x: centerX - paddedSide / 2,
            y: centerY - paddedSide / 2,
            width: paddedSide,
            height: paddedSide
        )
        
        // 2. CoreML用に黒背景・白線（太め）、Vision OCR用に白背景・黒線（細め）で画像をレンダリング
        let renderSize = CGSize(width: 300, height: 300)
        let coreMLImage = renderDrawing(drawing, in: squareBounds, size: renderSize, backgroundColor: .black, strokeColor: .white, lineWidth: 20.0)
        let visionImage = renderDrawing(drawing, in: squareBounds, size: renderSize, backgroundColor: .white, strokeColor: .black, lineWidth: 15.0)
        
        // デバッグ画像としてCoreML用（黒背景・白線）を保存
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("ocr_debug_digit.png")
        if let data = coreMLImage.pngData() {
            try? data.write(to: fileURL)
            print("[HR] デバッグ画像(CoreML用)を保存: \(fileURL.path)")
        }
        
        guard let coreMLCGImage = coreMLImage.cgImage,
              let visionCGImage = visionImage.cgImage else {
            print("[HR] cgImage が nil")
            return ""
        }
        
        // 3. CoreML (MNIST) による手書き数字認識（第一選択）
        // 期待される数字と一致し、かつ信頼度が 0.75 以上の場合のみ採用（誤判定による即時不合格を防ぐため）
        if let (predictedLabel, confidence) = await tryRecognizeCoreML(cgImage: coreMLCGImage) {
            if predictedLabel == expected && confidence >= 0.75 {
                print("[HR] CoreML で期待値と合致: \(predictedLabel) (信頼度: \(confidence))")
                return predictedLabel
            }
        }
        
        // 4. Vision OCR — .fast → .accurate のフォールバック（第二選択）
        if let result = await tryRecognize(cgImage: visionCGImage, level: .fast, expected: expected) {
            print("[HR] .fast で認識成功: \(result)")
            return result
        }
        
        if let result = await tryRecognize(cgImage: visionCGImage, level: .accurate, expected: expected) {
            print("[HR] .accurate で認識成功: \(result)")
            return result
        }
        
        // 5. 全ての認識が失敗した場合、ストローク形状から期待値の適合性を判定する幾何学的フォールバック
        if geometryMatch(drawing: drawing, expected: expected) {
            print("[HR] 形状分析適合により期待値 \(expected) として受理")
            return expected
        }
        
        print("[HR] 全ての認識で失敗")
        return ""
    }
    
    /// Vision OCR を実行
    private static func tryRecognize(cgImage: CGImage, level: VNRequestTextRecognitionLevel, expected: String) async -> String? {
        let levelName = level == .fast ? "fast" : "accurate"
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("[HR] [\(levelName)] Vision エラー: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                print("[HR] [\(levelName)] observations 数: \(observations.count)")
                for (index, observation) in observations.enumerated() {
                    let candidates = observation.topCandidates(20).map {
                        "\($0.string) (\(String(format: "%.2f", $0.confidence)))"
                    }
                    print("[HR] [\(levelName)] 候補[\(index)]: \(candidates.joined(separator: ", "))")
                }
                
                // 1. まず通常のマッピングで合致するものがあるか確認
                for observation in observations {
                    let candidates = observation.topCandidates(20)
                    for candidate in candidates {
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        let digit = mapRecognizedStringToDigit(text)
                        if digit == expected {
                            print("[HR] [\(levelName)] 期待値と一致する数字を検出: \(digit) (元: \(text))")
                            continuation.resume(returning: digit)
                            return
                        }
                    }
                }
                
                // 2. 期待値と直接一致するものがない場合、許容される誤認識マップ（expectedMatches）を使って判定
                let expectedMatches = getExpectedMatches(for: expected)
                for observation in observations {
                    let candidates = observation.topCandidates(20)
                    for candidate in candidates {
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if expectedMatches.contains(text) {
                            print("[HR] [\(levelName)] 許容マッピングにより期待値 \(expected) として受理 (元: \(text))")
                            continuation.resume(returning: expected)
                            return
                        }
                        
                        // 部分一致もチェック (例: "3?" や "?3" などのノイズ混じり)
                        for match in expectedMatches {
                            if text.contains(match) {
                                print("[HR] [\(levelName)] 部分一致許容により期待値 \(expected) として受理 (元: \(text))")
                                continuation.resume(returning: expected)
                                return
                            }
                        }
                    }
                }
                
                // 3. それでも見つからない場合は、通常通り最初に見つかった有効な数字を返す
                for observation in observations {
                    let candidates = observation.topCandidates(20)
                    for candidate in candidates {
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        let digit = mapRecognizedStringToDigit(text)
                        if !digit.isEmpty {
                            print("[HR] [\(levelName)] 代替数字を検出: \(digit) (元: \(text))")
                            continuation.resume(returning: digit)
                            return
                        }
                    }
                }
                
                continuation.resume(returning: nil)
            }
            
            request.recognitionLevel = level
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.0
            request.usesCPUOnly = true
            request.recognitionLanguages = ["en-US"]
            request.customWords = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[HR] [\(levelName)] Vision 実行失敗: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Vision が完全に失敗した場合のストローク形状分析フォールバック
    private static func geometryMatch(drawing: PKDrawing, expected: String) -> Bool {
        let bounds = drawing.bounds
        let aspectRatio = bounds.width / max(bounds.height, 1.0)
        let strokeCount = drawing.strokes.count
        
        print("[HR] [形状適合チェック] 期待値: \(expected), aspectRatio: \(String(format: "%.2f", aspectRatio)), strokes: \(strokeCount)")
        
        // 極端に小さい描画（ゴミなど）は却下
        guard bounds.width > 6 && bounds.height > 6 else {
            return false
        }
        
        switch expected {
        case "1":
            // 縦に非常に長い1〜2ストロークなら "1" とみなす
            return aspectRatio < 0.45 && strokeCount <= 2
        default:
            // 他の数字は誤判定を防ぐため、機械学習（CoreML/Vision OCR）の判定のみに委ねる
            return false
        }
    }
    
    /// 期待される数字ごとに、Vision が出力しうる許容範囲の誤認識文字列のセットを定義
    private static func getExpectedMatches(for expected: String) -> Set<String> {
        switch expected {
        case "0":
            return ["0", "o", "o.", "()", "co", "lo", "c0", "o0", "circle"]
        case "1":
            return ["1", "l", "i", "|", "/", "\\", "]", "[", "!", "j", "r", "slash"]
        case "2":
            return ["2", "z", "2z", "z2"]
        case "3":
            return ["3", "e", ")", "}", "{"]
        case "4":
            return ["4", "a", "h", "y", "x", "+", "*"]
        case "5":
            return ["5", "s", "5s", "s5", "£", "$"]
        case "6":
            return ["6", "b", "b6", "6b"]
        case "7":
            return ["7", "t", "v", "f", "7t", "t7", ">", "<"]
        case "8":
            return ["8", "&", "§"]
        case "9":
            return ["9", "q", "p", "9q", "q9"]
        default:
            return []
        }
    }
    
    /// Vision の認識結果を数字にマップ（数字前提の強制マッピング）
    private static func mapRecognizedStringToDigit(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstChar = clean.first else { return "" }
        
        // すでに数字の場合はそのまま返す
        if firstChar.isNumber {
            return String(firstChar)
        }
        
        let c = String(firstChar).lowercased()
        
        // 全文字・記号から最も形状が似ている数字への強制マッピング辞書
        let corrections: [String: String] = [
            // --- 1 に見える形状 ---
            "l": "1", "i": "1", "|": "1", "j": "1",
            "]": "1", "[": "1", "!": "1", "/": "1", "\\": "1",
            "1": "1",
            
            // --- 0 に見える形状 ---
            "o": "0", "•": "0", "°": "0",
            "()": "0", "co": "0", "lo": "0", "c0": "0", "o0": "0",
            
            // --- 2 に見える形状 ---
            "z": "2",
            
            // --- 3 に見える形状 ---
            "e": "3", ")": "3", "}": "3",
            
            // --- 4 に見える形状 ---
            "a": "4", "h": "4",
            
            // --- 5 に見える形状 ---
            "s": "5", "£": "5", "$": "5",
            
            // --- 6 に見える形状 ---
            "b": "6",
            
            // --- 7 に見える形状 ---
            "t": "7", "v": "7", "f": "7",
            
            // --- 8 に見える形状 ---
            "&": "8", "§": "8",
            
            // --- 9 に見える形状 ---
            "q": "9", "p": "9", "g": "9",
        ]
        
        if let corrected = corrections[c] {
            return corrected
        }
        
        return ""
    }
    
    /// CoreML (MNIST) を使用して手書き数字を分類します
    private static func tryRecognizeCoreML(cgImage: CGImage) async -> (String, Double)? {
        guard let model = try? MNIST(configuration: MLModelConfiguration()) else {
            print("[HR] CoreML (MNIST) モデルの初期化失敗")
            return nil
        }
        
        guard let visionModel = try? VNCoreMLModel(for: model.model) else {
            print("[HR] VNCoreMLModel の作成失敗")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    print("[HR] CoreML 推論エラー: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let predictedLabel = topResult.identifier
                let confidence = Double(topResult.confidence)
                print("[HR] CoreML 予測結果: \(predictedLabel), 信頼度: \(confidence)")
                continuation.resume(returning: (predictedLabel, confidence))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[HR] CoreML 実行失敗: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// PKDrawing を指定した背景色・線色・線幅で UIImage に描画します
    private static func renderDrawing(
        _ drawing: PKDrawing,
        in squareBounds: CGRect,
        size renderSize: CGSize,
        backgroundColor: UIColor,
        strokeColor: UIColor,
        lineWidth: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let scaleX = renderSize.width / squareBounds.width
        let scaleY = renderSize.height / squareBounds.height
        
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        return renderer.image { ctx in
            backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))
            
            strokeColor.setStroke()
            
            for stroke in drawing.strokes {
                let strokePath = stroke.path
                guard strokePath.count > 1 else { continue }
                
                let bezierPath = UIBezierPath()
                let totalSteps = max(strokePath.count * 3, 100)
                let maxParam = CGFloat(strokePath.count - 1)
                
                for step in 0..<totalSteps {
                    let t = CGFloat(step) / CGFloat(totalSteps - 1) * maxParam
                    let point = strokePath.interpolatedLocation(at: t)
                    let mapped = CGPoint(
                        x: (point.x - squareBounds.origin.x) * scaleX,
                        y: (point.y - squareBounds.origin.y) * scaleY
                    )
                    
                    if step == 0 {
                        bezierPath.move(to: mapped)
                    } else {
                        bezierPath.addLine(to: mapped)
                    }
                }
                
                bezierPath.lineWidth = lineWidth
                bezierPath.lineCapStyle = .round
                bezierPath.lineJoinStyle = .round
                bezierPath.stroke()
            }
        }
    }
}
