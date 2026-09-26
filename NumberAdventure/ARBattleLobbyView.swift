import SwiftUI
import MultipeerConnectivity

struct ARBattleLobbyView: View {
    let onDismiss: () -> Void
    
    @StateObject private var battleManager = LocalBattleManager.shared
    
    // ゲーム選択状態
    @State private var selectedMode: BattleGameMode = .coopMakeTen
    @State private var selectedRuleParam: Int = 10 // 倍数の場合は 2, 3, 5 等。位取りの場合は 100 等
    @State private var timeLimit: Double = 45.0
    
    // ゲーム開始トリガー
    @State private var activeGamePayload: GameStartPayload? = nil
    
    // アニメーション用
    @State private var isPulsingRadar = false
    
    struct GameStartPayload: Identifiable {
        let id = UUID()
        let mode: BattleGameMode
        let ruleParam: Int
        let seed: UInt64
        let timeLimit: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.18),
                        Color(red: 0.12, green: 0.08, blue: 0.28)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                StarryBackgroundView()
                
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView(isLandscape: isLandscape)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isLandscape ? 12 : 20) {
                            // 1. 接続ステータスカード（レーダー・相手表示）
                            connectionStatusCard(isLandscape: isLandscape)
                            
                            // 2. モード選択（接続中、またはシミュレータ等のソロテスト時）
                            modeSelectionSection(isLandscape: isLandscape)
                            
                            // 3. スタートボタン
                            startButtonSection(isLandscape: isLandscape)
                        }
                        .padding(.horizontal, isLandscape ? 32 : 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .fullScreenCover(item: $activeGamePayload) { payload in
                ARBattleGameView(
                    mode: payload.mode,
                    ruleParam: payload.ruleParam,
                    seed: payload.seed,
                    timeLimit: payload.timeLimit,
                    onDismiss: {
                        activeGamePayload = nil
                        battleManager.startAutoPairing()
                    }
                )
            }
        }
        .onAppear {
            battleManager.startAutoPairing()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsingRadar = true
            }
        }
        .onDisappear {
            battleManager.stopAll()
        }
        .onReceive(battleManager.$lastEvent) { event in
            guard let event = event else { return }
            if case .gameStart(let mode, let ruleParam, let seed, let limit) = event {
                // ゲスト側もホストの指示で自動スタート
                activeGamePayload = GameStartPayload(
                    mode: mode,
                    ruleParam: ruleParam,
                    seed: seed,
                    timeLimit: limit
                )
            }
        }
    }
    
    // MARK: - ヘッダー
    private func headerView(isLandscape: Bool) -> some View {
        HStack {
            Button(action: {
                battleManager.disconnect()
                onDismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: isLandscape ? 24 : 28))
                    Text("もどる")
                        .font(.headline)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Text("AR ふたりであそぶ")
                .font(.system(isLandscape ? .title3 : .title2, design: .rounded))
                .fontWeight(.black)
                .foregroundColor(.white)
            
            Spacer()
            
            // 右側の余白調整用
            Circle().fill(Color.clear).frame(width: isLandscape ? 24 : 28)
        }
        .padding(.horizontal, 16)
        .padding(.top, isLandscape ? 4 : 8)
    }
    
    // MARK: - 接続ステータスカード
    private func connectionStatusCard(isLandscape: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // レーダーアイコン
                ZStack {
                    Circle()
                        .stroke(battleManager.isConnected ? Color.green : Color.cyan, lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsingRadar ? 1.2 : 0.9)
                        .opacity(isPulsingRadar ? 0.3 : 0.8)
                    
                    Circle()
                        .fill(battleManager.isConnected ? Color.green : Color.cyan)
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: battleManager.isConnected ? "checkmark" : "antenna.radiowaves.left.and.right")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(battleManager.isConnected ? "つながったよ！" : "ちかくのおともだちを さがし中...")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if battleManager.isConnected {
                        Text("あいて: \(battleManager.connectedPeerName)")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    } else {
                        Text("相手の端末でも「ARふたりであそぶ」をひらいてね")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 再接続ボタン
                if !battleManager.isConnected {
                    Button(action: {
                        battleManager.startAutoPairing()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(battleManager.isConnected ? Color.green.opacity(0.5) : Color.cyan.opacity(0.3), lineWidth: 1.5)
            )
            
            // 未接続時でも見つかったピアがあればリスト表示
            if !battleManager.isConnected && !battleManager.discoveredPeers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("みつかった端末をタップしてせつぞく:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ForEach(battleManager.discoveredPeers, id: \.self) { peer in
                        Button(action: {
                            battleManager.invite(peer: peer)
                        }) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                Text(peer.displayName)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("つなぐ")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                            }
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - モード選択セクション
    private func modeSelectionSection(isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("あそぶゲームを えらぼう")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 10) {
                ForEach(BattleGameMode.allCases) { mode in
                    modeCard(mode: mode, isSelected: selectedMode == mode)
                }
            }
            
            // モードに応じたオプション設定
            if selectedMode == .battleMultiples {
                multiplesOptionPicker()
            } else if selectedMode == .battlePlaceValue {
                placeValueOptionPicker()
            }
        }
    }
    
    // モードカード
    private func modeCard(mode: BattleGameMode, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedMode = mode
                if mode == .battleMultiples {
                    selectedRuleParam = 3
                } else if mode == .battlePlaceValue {
                    selectedRuleParam = 100
                } else {
                    selectedRuleParam = 10
                }
            }
        }) {
            HStack(spacing: 14) {
                Image(systemName: mode.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .yellow : .white.opacity(0.6))
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .yellow : .white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
        }
    }
    
    // 倍数選択ピッカー
    private func multiplesOptionPicker() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("どの倍数で勝負する？")
                .font(.caption)
                .foregroundColor(.yellow)
            
            HStack(spacing: 10) {
                ForEach([2, 3, 5], id: \.self) { num in
                    Button(action: {
                        selectedRuleParam = num
                    }) {
                        Text("\(num)のばいすう")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(selectedRuleParam == num ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedRuleParam == num ? Color.yellow : Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // 位取り選択ピッカー
    private func placeValueOptionPicker() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("どの「かべ」をこえる？")
                .font(.caption)
                .foregroundColor(.yellow)
            
            HStack(spacing: 10) {
                ForEach([(10, "10のかべ(7〜)"), (100, "100のかべ(95〜)")], id: \.0) { item in
                    Button(action: {
                        selectedRuleParam = item.0
                    }) {
                        Text(item.1)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(selectedRuleParam == item.0 ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedRuleParam == item.0 ? Color.yellow : Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - スタートボタンセクション
    private func startButtonSection(isLandscape: Bool) -> some View {
        VStack(spacing: 10) {
            Button(action: {
                startGame()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text(battleManager.isConnected ? "ふたりでスタート！" : "ひとりでれんしゅう (テスト)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.black)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: battleManager.isConnected ? [Color.orange, Color.pink] : [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(24)
                .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
            }
            
            if !battleManager.isConnected {
                Text("※ 1台だけでも「ひとりでれんしゅう」として動作確認できます")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - ゲーム開始発火
    private func startGame() {
        let seed = UInt64(Date().timeIntervalSince1970 * 1000)
        
        // 相手がいる場合はイベント送信
        if battleManager.isConnected {
            battleManager.sendEvent(.gameStart(
                mode: selectedMode,
                ruleParam: selectedRuleParam,
                seed: seed,
                timeLimit: timeLimit
            ))
        }
        
        // 自分もゲーム画面へ遷移
        activeGamePayload = GameStartPayload(
            mode: selectedMode,
            ruleParam: selectedRuleParam,
            seed: seed,
            timeLimit: timeLimit
        )
    }
}
