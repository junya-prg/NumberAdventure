import SwiftUI
import AVFoundation
import ARKit
import Combine

struct ARShootingModeView: View {
    let startNum: Int
    let dotCount: Int
    let onDismiss: (Bool) -> Void
    
    // ゲームステート
    @State private var currentTarget: Int
    @State private var maxTarget: Int
    @State private var isCleared = false
    @State private var gameTime: Double = 0.0
    @State private var timerActive = false
    @State private var isARMode = true
    @State private var cameraPermissionGranted = false
    @State private var showPermissionAlert = false
    
    // リスタート用のビューID
    @State private var gameViewId = UUID()
    
    // 酔い止めモーションキューのオフセット
    @State private var motionCueOffset: CGSize = .zero
    
    // 星の付与用
    @State private var starsAdded = false
    
    // 照準の演出用
    @State private var isReticleScaling = false
    
    // 音声合成
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    
    // タイマー
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    init(startNum: Int, dotCount: Int, onDismiss: @escaping (Bool) -> Void) {
        self.startNum = startNum
        self.dotCount = dotCount
        self.onDismiss = onDismiss
        
        _currentTarget = State(initialValue: startNum)
        _maxTarget = State(initialValue: startNum + dotCount - 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // 1. ゲームの3D/AR描画部分
                if isARMode && ARWorldTrackingConfiguration.isSupported && cameraPermissionGranted {
                    ARGameViewContainer(
                        startNum: startNum,
                        count: dotCount,
                        currentTarget: currentTarget,
                        onTargetHit: handleTargetHit,
                        onWrongHit: handleWrongHit,
                        isARMode: true
                    )
                    .id(gameViewId)
                    .ignoresSafeArea()
                } else {
                    // AR非対応、またはパーミッションなし、または手動で3D宇宙に切り替えた場合
                    ARGameViewContainer(
                        startNum: startNum,
                        count: dotCount,
                        currentTarget: currentTarget,
                        onTargetHit: handleTargetHit,
                        onWrongHit: handleWrongHit,
                        isARMode: false
                    )
                    .id(gameViewId)
                    .ignoresSafeArea()
                }
                
                // 宇宙背景と操作説明（非ARの宇宙モードかつクリア前のみ）
                if (!isARMode || !cameraPermissionGranted || !ARWorldTrackingConfiguration.isSupported) && !isCleared {
                    VStack {
                        Spacer()
                        Text(ARWorldTrackingConfiguration.isSupported && !cameraPermissionGranted ? 
                             "⚠️ カメラが使えないため「うちゅうモード」でうごいています" :
                             "📱 デバイスをうごかすか、ドラッグして数字をさがそう！")
                            .font(.system(isLandscape ? .caption : .subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                            .padding(.bottom, isLandscape ? 40 : 80)
                    }
                    .allowsHitTesting(false) // タップをSceneKitに通すため
                }
                
                // 2. 画面中央の照準 (レティクル)
                if !isCleared {
                    ZStack {
                        // 外側のサークル
                        Circle()
                            .stroke(isARMode ? Color.orange : Color.cyan, lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .scaleEffect(isReticleScaling ? 0.8 : 1.0)
                        
                        // 十字のライン
                        Rectangle()
                            .fill(isARMode ? Color.orange : Color.cyan)
                            .frame(width: 12, height: 2)
                        
                        Rectangle()
                            .fill(isARMode ? Color.orange : Color.cyan)
                            .frame(width: 2, height: 12)
                        
                        // 中央のドット
                        Circle()
                            .fill(isARMode ? Color.orange : Color.cyan)
                            .frame(width: 4, height: 4)
                    }
                    .opacity(0.7)
                    .allowsHitTesting(false) // 照準自体はタップできない
                }
                
                // 3. UIオーバーレイ
                VStack(spacing: 0) {
                    // ヘッダーUI
                    HStack {
                        // もどるボタン
                        Button(action: {
                            speechSynthesizer.stop()
                            onDismiss(false)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                Text("もどる")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        // タイマー表示
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f秒", gameTime))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // AR / 宇宙 モード手動切り替えボタン (ARがサポートされている場合のみ表示)
                        if ARWorldTrackingConfiguration.isSupported && cameraPermissionGranted {
                            Button(action: {
                                withAnimation {
                                    isARMode.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isARMode ? "arkit" : "globe")
                                    Text(isARMode ? "AR" : "うちゅう")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isARMode ? Color.orange.opacity(0.7) : Color.cyan.opacity(0.7))
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, isLandscape ? 8 : 16)
                    
                    // ターゲット指示板
                    if !isCleared {
                        VStack(spacing: 4) {
                            Text("つぎのターゲット")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("\(currentTarget)")
                                .font(.system(isLandscape ? .title : .largeTitle, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(isARMode ? .orange : .cyan)
                                .shadow(color: (isARMode ? Color.orange : Color.cyan).opacity(0.5), radius: 8)
                            
                            Text("(\(startNum) 〜 \(maxTarget) まで)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, isLandscape ? 6 : 10)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(isARMode ? Color.orange.opacity(0.3) : Color.cyan.opacity(0.3), lineWidth: 1.5)
                                )
                        )
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
                
                // 4. クリア画面オーバーレイ
                if isCleared {
                    ZStack {
                        Color.black.opacity(0.8)
                            .ignoresSafeArea()
                        
                        // キラキラ背景パーティクル
                        ClearCelebrationParticlesView()
                        
                                            if isLandscape {
                            // 横向きの時の左右2カラムレイアウト（ボタン切れ解消）
                            HStack(spacing: 32) {
                                // 左側: トロフィーとクリアタイトル
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.yellow.opacity(0.15))
                                            .frame(width: 85, height: 85)
                                        
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 42))
                                            .foregroundColor(.yellow)
                                            .shadow(color: .yellow.opacity(0.5), radius: 10)
                                            .scaleEffect(starsAdded ? 1.2 : 0.8)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0), value: starsAdded)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("やったね！クリア！")
                                            .font(.system(.title3, design: .rounded))
                                            .fontWeight(.black)
                                            .foregroundColor(.white)
                                        
                                        Text("\(startNum) から \(maxTarget) まで\nじゅんばんに たおせたよ！")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.white.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // 右側: スコアと操作ボタン
                                VStack(spacing: 10) {
                                    VStack(spacing: 6) {
                                        Text(String(format: "タイム: %.1f 秒", gameTime))
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.yellow)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.system(size: 12))
                                            Text("+1 ほし を ゲットしたよ！")
                                                .font(.system(.caption, design: .rounded))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        resetGame()
                                    }) {
                                        Text("もういちど あそぶ")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .frame(width: 180)
                                            .padding(.vertical, 10)
                                            .background(Color.yellow)
                                            .cornerRadius(20)
                                            .shadow(color: .yellow.opacity(0.3), radius: 6, y: 3)
                                    }
                                    
                                    Button(action: {
                                        onDismiss(true)
                                    }) {
                                        Text("おわる")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 180)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.0)
                                            )
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // 縦向きの時のレイアウト
                            VStack(spacing: 24) {
                                Spacer(minLength: 0)
                                
                                ZStack {
                                    Circle()
                                        .fill(Color.yellow.opacity(0.15))
                                        .frame(width: 140, height: 140)
                                    
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 70))
                                        .foregroundColor(.yellow)
                                        .shadow(color: .yellow.opacity(0.5), radius: 15)
                                        .scaleEffect(starsAdded ? 1.2 : 0.8)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0), value: starsAdded)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("やったね！クリア！")
                                        .font(.system(.title, design: .rounded))
                                        .fontWeight(.black)
                                        .foregroundColor(.white)
                                    
                                    Text("\(startNum) から \(maxTarget) まで じゅんばんに たおせたよ！")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(String(format: "タイム: %.1f 秒", gameTime))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                        .padding(.top, 4)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("+1 ほし を ゲットしたよ！")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(20)
                                
                                VStack(spacing: 12) {
                                    Button(action: {
                                        resetGame()
                                    }) {
                                        Text("もういちど あそぶ")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                            .frame(width: 220)
                                            .padding(.vertical, 14)
                                            .background(Color.yellow)
                                            .cornerRadius(28)
                                            .shadow(color: .yellow.opacity(0.4), radius: 8, y: 4)
                                    }
                                    
                                    Button(action: {
                                        onDismiss(true)
                                    }) {
                                        Text("おわる")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 220)
                                            .padding(.vertical, 14)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(28)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 28)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                            )
                                    }
                                }
                                .padding(.top, 10)
                                
                                Spacer(minLength: 0)
                            }
                            .padding()
                        }
                    }
                    .transition(.opacity)
                }
                
                // 5. 酔い止めモーションキュードット（Appleの「車両モーションキュー」風演出）
                if !isCleared {
                    GeometryReader { screenGeo in
                        let width = screenGeo.size.width
                        let height = screenGeo.size.height
                        
                        ZStack {
                            // 左端のドット群
                            VStack(spacing: height / 8.0) {
                                ForEach(0..<5) { _ in
                                    Circle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .position(x: 12, y: height / 2)
                            
                            // 右端のドット群
                            VStack(spacing: height / 8.0) {
                                ForEach(0..<5) { _ in
                                    Circle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .position(x: width - 12, y: height / 2)
                        }
                        .offset(motionCueOffset)
                        .allowsHitTesting(false)
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
                startGame()
            }
            .onDisappear {
                speechSynthesizer.stop()
                timerActive = false
            }
            .onReceive(timer) { _ in
                if timerActive && !isCleared {
                    gameTime += 0.1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GyroscopeMovement"))) { notification in
                if let userInfo = notification.userInfo,
                   let dy = userInfo["deltaY"] as? Float,
                   let dx = userInfo["deltaX"] as? Float {
                    
                    let maxOffset: CGFloat = 18.0
                    
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.6)) {
                        // カメラの回転と逆方向にドットをオフセット
                        motionCueOffset.width = max(-maxOffset, min(maxOffset, motionCueOffset.width - CGFloat(dy * 85.0)))
                        motionCueOffset.height = max(-maxOffset, min(maxOffset, motionCueOffset.height - CGFloat(dx * 85.0)))
                    }
                    
                    // ゆっくり中央に戻るイージング
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            motionCueOffset.width *= 0.75
                            motionCueOffset.height *= 0.75
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UFOHitNotification"))) { notification in
                let type = notification.userInfo?["type"] as? String ?? "UFO"
                
                HapticManager.shared.playCorrectHaptic()
                SoundManager.shared.playCorrect()
                
                if type == "AI" {
                    let predicted = notification.userInfo?["predicted"] as? String ?? "謎"
                    let conf = notification.userInfo?["conf"] as? Double ?? 0.0
                    let percent = Int(conf * 100)
                    speechSynthesizer.speak("AIが手書き数字を判定したよ！これは \(predicted) だね！せいかいりつは \(percent) パーセントだよ！")
                } else if type == "Doughnut" {
                    speechSynthesizer.speak("ドーナツをゲットしたよ！もぐもぐ、おいしいね！")
                } else if type == "Crystal" {
                    speechSynthesizer.speak("きらきらクリスタルをみつけたよ！うつくしいね！")
                } else {
                    speechSynthesizer.speak("すごい！ユーフォーをやっつけたよ！ボーナススターだね！")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BonusSpawnNotification"))) { notification in
                let type = notification.userInfo?["type"] as? String ?? "UFO"
                
                if type == "AIDigit" {
                    speechSynthesizer.speak("あ！AIモニターロボットがあらわれたよ！てがき数字をねらいうとう！")
                } else if type == "Doughnut" {
                    speechSynthesizer.speak("あ！おいしそうなドーナツがとんできたよ！")
                } else if type == "Crystal" {
                    speechSynthesizer.speak("あ！きらきら光るクリスタルをみつけたよ！")
                } else {
                    speechSynthesizer.speak("あ！ユーフォーがやってきた！やっつけよう！")
                }
            }
        }
    }
    
    // MARK: - Game Control Logic
    
    private func checkCameraPermission() {
        // ARWorldTracking非サポートなら即座に非ARにする
        guard ARWorldTrackingConfiguration.isSupported else {
            cameraPermissionGranted = false
            isARMode = false
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = granted
                    if !granted {
                        self.isARMode = false
                    }
                }
            }
        case .denied, .restricted:
            cameraPermissionGranted = false
            isARMode = false
        @unknown default:
            cameraPermissionGranted = false
            isARMode = false
        }
    }
    
    private func startGame() {
        currentTarget = startNum
        isCleared = false
        gameTime = 0.0
        timerActive = true
        starsAdded = false
        
        // 音声による最初の指示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speechSynthesizer.speak("\(startNum)から じゅんばんに うとう！ \(startNum)をさがしてね！")
        }
    }
    
    private func resetGame() {
        resetGameStates()
        startGame()
    }
    
    private func resetGameStates() {
        currentTarget = startNum
        isCleared = false
        gameTime = 0.0
        timerActive = true
        starsAdded = false
        // ビューIDを更新してSceneKitシーンを完全再生成する
        gameViewId = UUID()
    }
    
    // 正解ターゲット命中時
    private func handleTargetHit(num: Int) {
        // 照準アニメーション
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            isReticleScaling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isReticleScaling = false
        }
        
        // 効果音とバイブ
        SoundManager.shared.playCorrect()
        HapticManager.shared.playCorrectHaptic()
        
        if currentTarget == maxTarget {
            // ゲームクリア！
            timerActive = false
            
            // 履歴と星の登録
            HistoryManager.shared.addRecord(
                mode: .arShooting,
                digits: String(startNum).count,
                questionNumber: startNum,
                isCorrect: true,
                userResponse: String(format: "%.1f秒", gameTime)
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isCleared = true
            }
            
            // 星の登場アニメーション用フラグ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    starsAdded = true
                }
            }
            
            speechSynthesizer.speak("やったね！ぜんぶクリア！")
        } else {
            // 次のターゲットへ
            currentTarget += 1
            
            // 読み上げ
            speechSynthesizer.speak("\(num)！せいかい！つぎは \(currentTarget) だよ")
        }
    }
    
    // 間違ったターゲット命中時
    private func handleWrongHit() {
        SoundManager.shared.playIncorrect()
        HapticManager.shared.playIncorrectHaptic()
        
        speechSynthesizer.speak("ちがうよ！\(currentTarget)をさがそう！")
    }
}

// MARK: - Clear Celebration Particles View (SwiftUI)
struct ClearCelebrationParticlesView: View {
    @State private var particles: [CelebrationParticle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width,
                        y: particle.y * size.height,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(particle.opacity)))
                }
            }
            .onAppear {
                spawnParticles()
            }
            .onChange(of: timeline.date) { _ in
                updateParticles()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func spawnParticles() {
        var temp: [CelebrationParticle] = []
        let colors: [Color] = [.orange, .yellow, .pink, .blue, .green, .purple]
        
        // 70個の紙吹雪を生成
        for i in 0..<70 {
            let isLeft = i % 2 == 0
            // 左右の下部コーナーから噴き出す初期配置
            let startX = isLeft ? CGFloat.random(in: 0.0...0.1) : CGFloat.random(in: 0.9...1.0)
            let startY = CGFloat.random(in: 0.8...0.95)
            
            // 初速度: 左右から内側かつ上方向へ
            let vx = isLeft ? CGFloat.random(in: 0.005 ... 0.015) : CGFloat.random(in: -0.015 ... -0.005)
            let vy = CGFloat.random(in: -0.035 ... -0.018)
            
            temp.append(CelebrationParticle(
                x: startX,
                y: startY,
                vx: vx,
                vy: vy,
                size: CGFloat.random(in: 3...7), // 小ぶりで上品なサイズ
                color: colors.randomElement()!,
                opacity: 1.0,
                life: CGFloat.random(in: 1.5...3.0) // 1.5s ~ 3.0s の寿命
            ))
        }
        particles = temp
    }
    
    private func updateParticles() {
        for i in 0..<particles.count {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            
            // 重力で落下
            particles[i].vy += 0.0006
            
            // 時間経過でフェードアウト
            particles[i].life -= 0.016
            particles[i].opacity = max(0, particles[i].life)
            
            // リセット再生成処理を廃止し、1回限りのお祝い演出とする
        }
    }
}

struct CelebrationParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    let color: Color
    var opacity: Double
    var life: CGFloat
}
