import SwiftUI

struct PlayView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    
    // ゲーム遷移状態
    @State private var activeGame: ActiveGame? = nil
    
    enum ActiveGame: Identifiable {
        var id: String {
            switch self {
            case .dotToDot(let start, let count): return "dotToDot_\(start)_\(count)"
            case .combine(let level, let target): return "combine_\(level)_\(target ?? 0)"
            case .arShooting(let start, let count): return "arShooting_\(start)_\(count)"
            }
        }
        case dotToDot(start: Int, count: Int)
        case combine(level: Int, target: Int? = nil)
        case arShooting(start: Int, count: Int)
    }
    
    // 設定選択中のフラグ
    @State private var showDotSettings = false
    @State private var showCombineSettings = false
    @State private var showARShootingSettings = false
    @State private var showARBattleLobby = false
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.12),
                        Color(red: 0.08, green: 0.1, blue: 0.22)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                StarryBackgroundView()
                
                VStack(spacing: 0) {
                    VStack(spacing: isLandscape ? 12 : 24) {
                        // 上部ヘッダー
                        HStack {
                            Text("すうじであそぶ")
                                .font(.system(isLandscape ? .title2 : .title, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // 星の数
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: isLandscape ? 14 : 18, weight: .bold))
                                Text("\(historyManager.starsCount)")
                                    .font(.system(isLandscape ? .body : .headline, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, isLandscape ? 10 : 14)
                            .padding(.vertical, isLandscape ? 4 : 8)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(20)
                        }
                        .padding(.top, isLandscape ? 4 : 10)
                        
                        if !isLandscape {
                            Text("ゲームを えらんで チャレンジしよう！")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // カードメニュー
                        ScrollView(showsIndicators: false) {
                            if isLandscape {
                                HStack(alignment: .top, spacing: 16) {
                                    // 1. てんつなぎ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "てんつなぎ (Dot-to-Dot)",
                                            description: "じゅんばんに せんをつないで、10や100の「くらい」をまたぐ 数の変化を体感しよう！",
                                            icon: "sparkles",
                                            color: .yellow,
                                            isLandscape: true
                                        ) {
                                            withAnimation(.spring()) {
                                                showDotSettings.toggle()
                                                showCombineSettings = false
                                                showARShootingSettings = false
                                            }
                                        }
                                        
                                        if showDotSettings {
                                            VStack(spacing: 8) {
                                                Text("どの「かべ」に ちょうせん する？")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.yellow)
                                                
                                                VStack(spacing: 8) {
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "1けたのかべ", subtitle: "3〜8 など") {
                                                            activeGame = .dotToDot(start: Int.random(in: 1...5), count: 6)
                                                        }
                                                        DifficultyButton(title: "10のかべ", subtitle: "7〜12 など") {
                                                            activeGame = .dotToDot(start: Int.random(in: 6...9), count: 6)
                                                        }
                                                    }
                                                    
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "十の位のかべ", subtitle: "26〜32, 55〜61") {
                                                            let starts = [26, 36, 46, 55, 66, 76, 85]
                                                            activeGame = .dotToDot(start: starts.randomElement()!, count: 7)
                                                        }
                                                        DifficultyButton(title: "100のかべ", subtitle: "95〜102, 137〜144") {
                                                            let starts = [95, 137, 236]
                                                            activeGame = .dotToDot(start: starts.randomElement()!, count: 8)
                                                        }
                                                    }
                                                    
                                                    DifficultyButton(title: "1000のかべ", subtitle: "995〜1002 など") {
                                                        activeGame = .dotToDot(start: Int.random(in: 993...999), count: 8)
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding(10)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // 2. ARすうじシューティング
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "ARすうじシューティング",
                                            description: "カメラでおへやを見わたして、つぎの数字をさがしてビームでうとう！",
                                            icon: "scope",
                                            color: .orange,
                                            isLandscape: true
                                        ) {
                                            withAnimation(.spring()) {
                                                showARShootingSettings.toggle()
                                                showDotSettings = false
                                                showCombineSettings = false
                                            }
                                        }
                                        
                                        if showARShootingSettings {
                                            VStack(spacing: 8) {
                                                Text("どの「かべ」に ちょうせん する？")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                                
                                                VStack(spacing: 8) {
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "1けたのかべ", subtitle: "3〜8 など") {
                                                            activeGame = .arShooting(start: Int.random(in: 1...5), count: 6)
                                                        }
                                                        DifficultyButton(title: "10のかべ", subtitle: "7〜12 など") {
                                                            activeGame = .arShooting(start: Int.random(in: 6...9), count: 6)
                                                        }
                                                    }
                                                    
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "十の位のかべ", subtitle: "26〜32, 55〜61") {
                                                            let starts = [26, 36, 46, 55, 66, 76, 85]
                                                            activeGame = .arShooting(start: starts.randomElement()!, count: 7)
                                                        }
                                                        DifficultyButton(title: "100のかべ", subtitle: "95〜102, 137〜144") {
                                                            let starts = [95, 137, 236]
                                                            activeGame = .arShooting(start: starts.randomElement()!, count: 8)
                                                        }
                                                    }
                                                    
                                                    DifficultyButton(title: "1000のかべ", subtitle: "995〜1002 など") {
                                                        activeGame = .arShooting(start: Int.random(in: 993...999), count: 8)
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding(10)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // 3. あわせていくつ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "あわせていくつ (数の合成)",
                                            description: "てんびんのカゴに 1, 5, 10のジェムをいれて、おだいの数にすばやくあわせよう！",
                                            icon: "scale.3d",
                                            color: .green,
                                            isLandscape: true
                                        ) {
                                            withAnimation(.spring()) {
                                                showCombineSettings.toggle()
                                                showDotSettings = false
                                                showARShootingSettings = false
                                            }
                                        }
                                        
                                        if showCombineSettings {
                                            VStack(spacing: 8) {
                                                Text("むずかしさを えらんでね")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                
                                                VStack(spacing: 8) {
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "レベル 1", subtitle: "10まで") {
                                                            activeGame = .combine(level: 1)
                                                        }
                                                        DifficultyButton(title: "レベル 2", subtitle: "くりあがり") {
                                                            activeGame = .combine(level: 2)
                                                        }
                                                    }
                                                    HStack(spacing: 8) {
                                                        DifficultyButton(title: "レベル 3", subtitle: "100まで") {
                                                            activeGame = .combine(level: 3)
                                                        }
                                                        DifficultyButton(title: "レベル 4", subtitle: "4けたのくらい") {
                                                            activeGame = .combine(level: 4)
                                                        }
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding(10)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // 4. ARふたりであそぶ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "ARふたりであそぶ (通信)",
                                            description: "Bluetoothで近くのおともだちとつながる！あわせて10の協力や倍数・位取り対戦！",
                                            icon: "person.2.wave.2.fill",
                                            color: .purple,
                                            isLandscape: true
                                        ) {
                                            showARBattleLobby = true
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                VStack(spacing: 20) {
                                    // 1. てんつなぎ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "てんつなぎ (Dot-to-Dot)",
                                            description: "じゅんばんに せんをつないで、10や100の「くらい」をまたぐ 数の変化を体感しよう！",
                                            icon: "sparkles",
                                            color: .yellow
                                        ) {
                                            withAnimation(.spring()) {
                                                showDotSettings.toggle()
                                                showCombineSettings = false
                                                showARShootingSettings = false
                                            }
                                        }
                                        
                                        if showDotSettings {
                                            VStack(spacing: 12) {
                                                Text("どの「かべ」に ちょうせん する？")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.yellow)
                                                
                                                VStack(spacing: 10) {
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "1けたのかべ", subtitle: "3〜8 など") {
                                                            activeGame = .dotToDot(start: Int.random(in: 1...5), count: 6)
                                                        }
                                                        DifficultyButton(title: "10のかべ", subtitle: "7〜12 など") {
                                                            activeGame = .dotToDot(start: Int.random(in: 6...9), count: 6)
                                                        }
                                                    }
                                                    
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "十の位のかべ", subtitle: "26〜32, 55〜61") {
                                                            let starts = [26, 36, 46, 55, 66, 76, 85]
                                                            activeGame = .dotToDot(start: starts.randomElement()!, count: 7)
                                                        }
                                                        DifficultyButton(title: "100のかべ", subtitle: "95〜102, 137〜144") {
                                                            let starts = [95, 137, 236]
                                                            activeGame = .dotToDot(start: starts.randomElement()!, count: 8)
                                                        }
                                                    }
                                                    
                                                    DifficultyButton(title: "1000のかべ", subtitle: "995〜1002 など") {
                                                        activeGame = .dotToDot(start: Int.random(in: 993...999), count: 8)
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    
                                    // 2. ARすうじシューティング
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "ARすうじシューティング",
                                            description: "カメラでおへやを見わたして、つぎの数字をさがしてビームでうとう！",
                                            icon: "scope",
                                            color: .orange
                                        ) {
                                            withAnimation(.spring()) {
                                                showARShootingSettings.toggle()
                                                showDotSettings = false
                                                showCombineSettings = false
                                            }
                                        }
                                        
                                        if showARShootingSettings {
                                            VStack(spacing: 12) {
                                                Text("どの「かべ」に ちょうせん する？")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                                
                                                VStack(spacing: 10) {
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "1けたのかべ", subtitle: "3〜8 など") {
                                                            activeGame = .arShooting(start: Int.random(in: 1...5), count: 6)
                                                        }
                                                        DifficultyButton(title: "10のかべ", subtitle: "7〜12 など") {
                                                            activeGame = .arShooting(start: Int.random(in: 6...9), count: 6)
                                                        }
                                                    }
                                                    
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "十の位のかべ", subtitle: "26〜32, 55〜61") {
                                                            let starts = [26, 36, 46, 55, 66, 76, 85]
                                                            activeGame = .arShooting(start: starts.randomElement()!, count: 7)
                                                        }
                                                        DifficultyButton(title: "100のかべ", subtitle: "95〜102, 137〜144") {
                                                            let starts = [95, 137, 236]
                                                            activeGame = .arShooting(start: starts.randomElement()!, count: 8)
                                                        }
                                                    }
                                                    
                                                    DifficultyButton(title: "1000のかべ", subtitle: "995〜1002 など") {
                                                        activeGame = .arShooting(start: Int.random(in: 993...999), count: 8)
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    
                                    // 3. あわせていくつ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "あわせていくつ (数の合成)",
                                            description: "てんびんのカゴに 1, 5, 10のジェムをいれて、おだいの数にすばやくあわせよう！",
                                            icon: "scale.3d",
                                            color: .green
                                        ) {
                                            withAnimation(.spring()) {
                                                showCombineSettings.toggle()
                                                showDotSettings = false
                                                showARShootingSettings = false
                                            }
                                        }
                                        
                                        if showCombineSettings {
                                            VStack(spacing: 10) {
                                                Text("むずかしさを えらんでね")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                
                                                VStack(spacing: 8) {
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "レベル 1", subtitle: "10まで") {
                                                            activeGame = .combine(level: 1)
                                                        }
                                                        DifficultyButton(title: "レベル 2", subtitle: "くりあがり") {
                                                            activeGame = .combine(level: 2)
                                                        }
                                                    }
                                                    HStack(spacing: 12) {
                                                        DifficultyButton(title: "レベル 3", subtitle: "100まで") {
                                                            activeGame = .combine(level: 3)
                                                        }
                                                        DifficultyButton(title: "レベル 4", subtitle: "4けたのくらい") {
                                                            activeGame = .combine(level: 4)
                                                        }
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(20)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                                    
                                    // 4. ARふたりであそぶ
                                    VStack(spacing: 0) {
                                        PlayMenuCard(
                                            title: "ARふたりであそぶ (通信対戦・協力)",
                                            description: "近くのお友だちとBluetooth通信でつながる！\n「あわせて10」の協力や、「倍数」「位取り」のスピードバトル！",
                                            icon: "person.2.wave.2.fill",
                                            color: .purple
                                        ) {
                                            showARBattleLobby = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 0)
                    
                    // バナー広告を直接配置
                    BannerAdView()
                }
            }
        }
        .fullScreenCover(item: $activeGame) { game in
            switch game {
            case .dotToDot(let start, let count):
                DotToDotModeView(startNum: start, dotCount: count) { success in
                    activeGame = nil
                }
            case .combine(let level, let target):
                CombineModeView(level: level, targetNumber: target) { success in
                    activeGame = nil
                }
            case .arShooting(let start, let count):
                ARShootingModeView(startNum: start, dotCount: count) { success in
                    activeGame = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showARBattleLobby) {
            ARBattleLobbyView {
                showARBattleLobby = false
            }
        }
        .onAppear {
            checkRetryRequest()
        }
        .onChange(of: historyManager.retryRequest) { _ in
            checkRetryRequest()
        }
    }
    
    private func checkRetryRequest() {
        guard let request = historyManager.retryRequest else { return }
        
        switch request.mode {
        case .dotToDot:
            let start = request.number
            let count: Int
            if start >= 990 { count = 8 }
            else if start >= 90 { count = 8 }
            else if start >= 20 { count = 7 }
            else if start >= 6 { count = 6 }
            else { count = 6 }
            
            activeGame = .dotToDot(start: start, count: count)
            historyManager.retryRequest = nil
            
        case .combine:
            let level: Int
            if request.digits == 4 { level = 4 }
            else if request.digits == 2 { level = 3 }
            else {
                level = request.number > 10 ? 2 : 1
            }
            
            activeGame = .combine(level: level, target: request.number)
            historyManager.retryRequest = nil
            
        case .arShooting:
            let start = request.number
            let count: Int
            if start >= 990 { count = 8 }
            else if start >= 90 { count = 8 }
            else if start >= 20 { count = 7 }
            else if start >= 6 { count = 6 }
            else { count = 6 }
            
            activeGame = .arShooting(start: start, count: count)
            historyManager.retryRequest = nil
            
        default:
            break
        }
    }
}

// MARK: - Play Menu Card
struct PlayMenuCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    var isLandscape: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isLandscape ? 12 : 20) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: isLandscape ? 48 : 64, height: isLandscape ? 48 : 64)
                    
                    Image(systemName: icon)
                        .font(.system(size: isLandscape ? 20 : 28, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(isLandscape ? .body : .title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1.5)
                        .lineLimit(isLandscape ? 2 : nil)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(isLandscape ? 12 : 20)
            .background(Color.white.opacity(0.06))
            .cornerRadius(isLandscape ? 20 : 28)
            .overlay(
                RoundedRectangle(cornerRadius: isLandscape ? 20 : 28)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Difficulty Button
struct DifficultyButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
