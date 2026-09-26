import SwiftUI
import AVFoundation
import ARKit
import Combine

struct ARBattleGameView: View {
    let mode: BattleGameMode
    let ruleParam: Int
    let seed: UInt64
    let timeLimit: Double
    let onDismiss: () -> Void
    
    @ObservedObject var battleManager = LocalBattleManager.shared
    @ObservedObject var historyManager = HistoryManager.shared
    
    // ゲーム進行状態
    @State private var remainingTime: Double
    @State private var isGameActive = false
    @State private var isGameOver = false
    
    // スコア管理
    @State private var myScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var coopPairsCount: Int = 0
    
    // 配置される数字の配列
    @State private var numbers: [Int] = []
    
    // ロック＆撃破状態
    @State private var myLockTarget: Int? = nil
    @State private var opponentLockTarget: Int? = nil
    @State private var removedTargets: Set<Int> = []
    @State private var matchedPair: (Int, Int)? = nil
    
    // 対戦レース用（位取りレース）
    @State private var currentRaceTarget: Int = 0
    
    // 表示モード
    @State private var isARMode: Bool = true
    @State private var cameraPermissionGranted: Bool = false
    
    // 音声＆ハプティクス
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    
    // タイマー
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // リザルト演出用
    @State private var showResultOverlay = false
    @State private var starsAdded = false
    @State private var isReticleScaling = false
    
    init(mode: BattleGameMode, ruleParam: Int, seed: UInt64, timeLimit: Double, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.ruleParam = ruleParam
        self.seed = seed
        self.timeLimit = timeLimit
        self.onDismiss = onDismiss
        _remainingTime = State(initialValue: timeLimit)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // 1. AR / 3D空間コンテナ (画面のどこをタップしても中央の照準に向けて発射)
                if !numbers.isEmpty {
                    ARBattleGameViewContainer(
                        gameMode: mode,
                        ruleParam: ruleParam,
                        seed: seed,
                        numbers: numbers,
                        isARMode: isARMode && cameraPermissionGranted,
                        onTargetTapped: handleTargetTapped,
                        onShoot: handleShoot,
                        myLockTarget: $myLockTarget,
                        opponentLockTarget: $opponentLockTarget,
                        removedTargets: $removedTargets,
                        matchedPair: $matchedPair
                    )
                    .ignoresSafeArea()
                }
                
                // 2. 画面中央の照準
                if !isGameOver {
                    reticleView()
                }
                
                // 3. HUDヘッダー & スコアボード
                VStack(spacing: 0) {
                    headerHUD(isLandscape: isLandscape)
                    
                    // お題バナー
                    missionBanner(isLandscape: isLandscape)
                        .padding(.top, 8)
                    
                    Spacer()
                        .allowsHitTesting(false)
                    
                    // 協力モード時のロックオンガイド (表示のみ)
                    if mode == .coopMakeTen && !isGameOver {
                        coopLockGuide(isLandscape: isLandscape)
                            .allowsHitTesting(false)
                            .padding(.bottom, isLandscape ? 12 : 24)
                    }
                }
                
                // 4. ゲームオーバー・リザルト画面
                if showResultOverlay {
                    resultOverlay(isLandscape: isLandscape)
                }
            }
        }
        .onAppear {
            checkCameraPermission()
            setupGameData()
            isGameActive = true
            speakMission()
        }
        .onDisappear {
            speechSynthesizer.stop()
            battleManager.disconnect()
        }
        .onReceive(timer) { _ in
            guard isGameActive, !isGameOver else { return }
            if remainingTime > 0.1 {
                remainingTime -= 0.1
            } else {
                remainingTime = 0
                finishGame()
            }
        }
        .onReceive(battleManager.$lastEvent) { event in
            guard let event = event else { return }
            handleRemoteEvent(event)
        }
    }
    
    // MARK: - カメラ権限チェック
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = granted
                }
            }
        default:
            cameraPermissionGranted = false
        }
    }
    
    // MARK: - ゲームデータ初期化
    private func setupGameData() {
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        switch mode {
        case .coopMakeTen:
            // 10のペアになる数字を多数配置 (1〜9)
            var generated: [Int] = []
            let pairsCount = 14
            for _ in 0..<pairsCount {
                let a = Int.random(in: 1...9, using: &rng)
                let b = 10 - a
                generated.append(a)
                generated.append(b)
            }
            // ランダムにシャッフル
            generated.shuffle(using: &rng)
            self.numbers = generated
            
        case .battleMultiples:
            // 倍数とお邪魔数字を散りばめる
            let multiple = ruleParam // 2, 3, 5など
            var generated: [Int] = []
            // 正解の倍数
            for i in 1...10 {
                generated.append(i * multiple)
            }
            // ダミー数字
            for _ in 0..<12 {
                let dummy = Int.random(in: 1...50, using: &rng)
                if dummy % multiple != 0 {
                    generated.append(dummy)
                }
            }
            generated.shuffle(using: &rng)
            self.numbers = generated
            
        case .battlePlaceValue:
            // 位取りの壁 (95〜104など)
            let start = ruleParam == 100 ? 95 : (ruleParam == 10 ? 7 : 26)
            let count = 10
            let list = Array(start..<(start + count))
            self.numbers = list
            self.currentRaceTarget = start
        }
    }
    
    // MARK: - お題音声読み上げ
    private func speakMission() {
        let text: String
        switch mode {
        case .coopMakeTen:
            text = "あわせて10になるペアを、ふたりでみつけよう！"
        case .battleMultiples:
            text = "\(ruleParam)のばいすうを、はやくみつけて撃ちぬこう！"
        case .battlePlaceValue:
            text = "\(currentRaceTarget)から じゅんばんに はやく撃とう！"
        }
        speechSynthesizer.speak(text)
    }
    
    // MARK: - 発射時アクション (画面タップで即時発射＆照準リアクション)
    private func handleShoot() {
        guard isGameActive, !isGameOver else { return }
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            isReticleScaling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isReticleScaling = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - タップ判定処理
    private func handleTargetTapped(_ target: Int) {
        guard isGameActive, !isGameOver else { return }
        guard !removedTargets.contains(target) else { return }
        
        switch mode {
        case .coopMakeTen:
            handleCoopTap(target)
            
        case .battleMultiples:
            handleMultiplesTap(target)
            
        case .battlePlaceValue:
            handlePlaceValueTap(target)
        }
    }
    
    // ① あわせて10（協力）のタップ処理
    private func handleCoopTap(_ target: Int) {
        // すでに自分が同じ数字をロック中なら解除
        if myLockTarget == target {
            myLockTarget = nil
            battleManager.sendEvent(.unlock(targetNumber: target, playerUUID: battleManager.myUUID))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        
        // 相手がロックしている数字とペアになるかチェック
        if let opponentNum = opponentLockTarget {
            if opponentNum + target == 10 {
                // ペア成立！！
                SoundManager.shared.playCorrect()
                HapticManager.shared.playCorrectHaptic()
                
                myScore += 100
                coopPairsCount += 1
                matchedPair = (opponentNum, target)
                
                // 消去予約
                removedTargets.insert(opponentNum)
                removedTargets.insert(target)
                
                myLockTarget = nil
                opponentLockTarget = nil
                
                // 通信で同期
                battleManager.sendEvent(.pairSuccess(
                    num1: opponentNum,
                    num2: target,
                    sum: 10,
                    totalScore: myScore
                ))
                
                speechSynthesizer.speak("\(opponentNum)たす\(target)は10！")
                
                // リセット
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.matchedPair = nil
                }
                return
            }
        }
        
        // 通常の自分のロックオン
        myLockTarget = target
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        battleManager.sendEvent(.lockOn(
            targetNumber: target,
            playerUUID: battleManager.myUUID,
            playerName: battleManager.myName
        ))
    }
    
    // ② 倍数バスターズ（対戦）のタップ処理
    private func handleMultiplesTap(_ target: Int) {
        let multiple = ruleParam
        if target % multiple == 0 {
            // 正解！
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
            myScore += 100
            removedTargets.insert(target)
            
            battleManager.sendEvent(.targetHit(
                targetNumber: target,
                playerUUID: battleManager.myUUID,
                playerName: battleManager.myName,
                points: 100
            ))
            
            // 全倍数が撃破されたかチェック
            let remainingMultiples = numbers.filter { !removedTargets.contains($0) && $0 % multiple == 0 }
            if remainingMultiples.isEmpty {
                finishGame()
            }
        } else {
            // お手つき
            SoundManager.shared.playIncorrect()
            HapticManager.shared.playIncorrectHaptic()
            myScore = max(0, myScore - 30)
        }
    }
    
    // ③ 位取りレース（対戦）のタップ処理
    private func handlePlaceValueTap(_ target: Int) {
        if target == currentRaceTarget {
            // 正解！
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
            myScore += 100
            removedTargets.insert(target)
            currentRaceTarget += 1
            
            battleManager.sendEvent(.targetHit(
                targetNumber: target,
                playerUUID: battleManager.myUUID,
                playerName: battleManager.myName,
                points: 100
            ))
            
            // 完走チェック
            if removedTargets.count >= numbers.count {
                finishGame()
            }
        } else {
            // 順番が違う
            SoundManager.shared.playIncorrect()
            HapticManager.shared.playIncorrectHaptic()
        }
    }
    
    // MARK: - 相手からの通信イベント受信処理
    private func handleRemoteEvent(_ event: BattleEvent) {
        switch event {
        case .lockOn(let target, _, _):
            self.opponentLockTarget = target
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case .unlock(let target, _):
            if self.opponentLockTarget == target {
                self.opponentLockTarget = nil
            }
            
        case .pairSuccess(let n1, let n2, _, let total):
            // 相手側でペアが成立した通知
            self.removedTargets.insert(n1)
            self.removedTargets.insert(n2)
            self.myLockTarget = nil
            self.opponentLockTarget = nil
            self.coopPairsCount += 1
            self.myScore = total
            self.matchedPair = (n1, n2)
            
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.matchedPair = nil
            }
            
        case .targetHit(let target, _, _, let points):
            // 相手が数字を撃破
            self.removedTargets.insert(target)
            self.opponentScore += points
            SoundManager.shared.playCorrect()
            
            if mode == .battlePlaceValue && target == currentRaceTarget {
                currentRaceTarget += 1
            }
            
        case .gameFinished(_, _, let scoreA, let scoreB):
            self.opponentScore = (battleManager.isHost ? scoreB : scoreA)
            finishGame()
            
        case .leaveGame:
            isGameActive = false
            onDismiss()
            
        default:
            break
        }
    }
    
    // MARK: - ゲーム終了処理
    private func finishGame() {
        guard !isGameOver else { return }
        isGameOver = true
        isGameActive = false
        
        SoundManager.shared.playCorrect()
        HapticManager.shared.playCorrectHaptic()
        
        // 星の付与
        if !starsAdded {
            starsAdded = true
            let earnedStars = max(3, (mode == .coopMakeTen ? coopPairsCount : max(1, myScore / 100)))
            historyManager.starsCount += earnedStars
        }
        
        withAnimation(.spring()) {
            showResultOverlay = true
        }
    }
    
    // MARK: - UIコンポーネント: ヘッダーHUD
    private func headerHUD(isLandscape: Bool) -> some View {
        HStack {
            // もどるボタン
            Button(action: {
                battleManager.disconnect()
                onDismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                    Text("もどる")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            
            Spacer()
            
            // 残り時間
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(remainingTime <= 10 ? .red : .yellow)
                Text(String(format: "%.1f秒", remainingTime))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(remainingTime <= 10 ? .red : .white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            
            Spacer()
            
            // スコア表示
            if mode == .coopMakeTen {
                // 協力スコア
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("ペア: \(coopPairsCount)くみ")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            } else {
                // 対戦スコア (自分 vs 相手)
                HStack(spacing: 8) {
                    Text("じぶん: \(myScore)")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("vs")
                        .foregroundColor(.white.opacity(0.6))
                    Text("あいて: \(opponentScore)")
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
            
            // カメラ/3D切り替えボタン (AR対応端末のみ)
            if ARWorldTrackingConfiguration.isSupported {
                Button(action: {
                    withAnimation {
                        isARMode.toggle()
                    }
                }) {
                    Image(systemName: isARMode ? "camera.fill" : "globe")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(isARMode ? Color.orange : Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isLandscape ? 4 : 8)
    }
    
    // MARK: - UIコンポーネント: お題バナー
    private func missionBanner(isLandscape: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                switch mode {
                case .coopMakeTen:
                    Text("あわせて 10 をつくろう！")
                        .font(.system(isLandscape ? .headline : .title3, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("ふたりで たして10になる数字を えらんでね")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                case .battleMultiples:
                    Text("\(ruleParam) の ばいすう を うて！")
                        .font(.system(isLandscape ? .headline : .title3, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Text("相手より早く \(ruleParam)でわれる数字を見つけよう")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                case .battlePlaceValue:
                    Text("つぎの数字: [ \(currentRaceTarget) ]")
                        .font(.system(isLandscape ? .headline : .title3, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.yellow)
                    Text("順番に早く撃ちぬいてゴールをめざせ！")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }
    
    // MARK: - UIコンポーネント: 協力ロックオンガイド
    private func coopLockGuide(isLandscape: Bool) -> some View {
        HStack(spacing: 16) {
            // 自分のロック
            HStack(spacing: 6) {
                Circle().fill(Color.orange).frame(width: 12, height: 12)
                Text(myLockTarget != nil ? "じぶん: [ \(myLockTarget!) ]" : "じぶん: えらんでね")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("+")
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(.yellow)
            
            // 相手のロック
            HStack(spacing: 6) {
                Circle().fill(Color.cyan).frame(width: 12, height: 12)
                Text(opponentLockTarget != nil ? "\(battleManager.connectedPeerName): [ \(opponentLockTarget!) ]" : "あいて: まち...")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75))
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - UIコンポーネント: 照準 (レティクル)
    private func reticleView() -> some View {
        ZStack {
            // 外枠サークル
            Circle()
                .stroke(isReticleScaling ? Color.orange : Color.yellow, lineWidth: isReticleScaling ? 3 : 2)
                .frame(width: 44, height: 44)
                .scaleEffect(isReticleScaling ? 0.8 : 1.0)
            
            // 水平十字ライン
            Rectangle()
                .fill(isReticleScaling ? Color.orange : Color.yellow)
                .frame(width: 12, height: 2)
            
            // 垂直十字ライン
            Rectangle()
                .fill(isReticleScaling ? Color.orange : Color.yellow)
                .frame(width: 2, height: 12)
            
            // 中央ドット
            Circle()
                .fill(isReticleScaling ? Color.orange : Color.yellow)
                .frame(width: 4, height: 4)
        }
        .opacity(0.85)
        .allowsHitTesting(false)
    }
    
    // MARK: - UIコンポーネント: リザルト画面
    private func resultOverlay(isLandscape: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: isLandscape ? 12 : 20) {
                Text(mode == .coopMakeTen ? "🌟 ミッションクリア！ 🌟" : "🏁 ゲームしゅうりょう！ 🏁")
                    .font(.system(isLandscape ? .title2 : .largeTitle, design: .rounded))
                    .fontWeight(.black)
                    .foregroundColor(.yellow)
                
                if mode == .coopMakeTen {
                    VStack(spacing: 8) {
                        Text("ふたりでつなげたペア")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(coopPairsCount) くみ！")
                            .font(.system(size: isLandscape ? 36 : 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("最高のチームワークでした！")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    }
                } else {
                    VStack(spacing: 12) {
                        let isWin = myScore >= opponentScore
                        Text(isWin ? "🎉 あなたの かち！ 🎉" : "👏 ナイスファイト！")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(isWin ? .orange : .cyan)
                        
                        HStack(spacing: 30) {
                            VStack {
                                Text("じぶん")
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(myScore)")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            Text("-")
                                .font(.title)
                                .foregroundColor(.white)
                            VStack {
                                Text(battleManager.connectedPeerName)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(opponentScore)")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
                
                // 星ゲット表示
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    Text("星を 3こ ゲットしたよ！")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(20)
                
                // もういちど / おわるボタン
                Button(action: {
                    battleManager.disconnect()
                    onDismiss()
                }) {
                    Text("ロビーにもどる")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(30)
                        .shadow(radius: 5)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.2))
            )
            .padding(20)
        }
    }
}
