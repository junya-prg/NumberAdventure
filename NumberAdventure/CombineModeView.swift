import SwiftUI

struct CombineModeView: View {
    let level: Int // 1 (10まで), 2 (繰り上がり), 3 (100まで), 4 (4桁位取り)
    let completionHandler: (Bool) -> Void
    
    // 再挑戦用の初期パラメータ
    private let retryTargetNumber: Int?
    private let retryInitialLeft: Int?
    
    @State private var isFirstLoad = true
    
    // 問題の状態
    @State private var targetNumber: Int = 10
    @State private var initialLeft: Int = 5
    
    // レベル1-3用の右カゴに入れたジェムの履歴 (まとまり学習用)
    @State private var addedGems: [Int] = []
    
    private var currentRight: Int {
        addedGems.reduce(0, +)
    }
    
    // レベル4（4桁位取り）用の状態
    @State private var thousandsCount: Int = 0
    @State private var hundredsCount: Int = 0
    @State private var tensCount: Int = 0
    @State private var onesCount: Int = 0
    
    @State private var showResultOverlay = false
    @State private var isCorrect = false
    
    // 物理シミュレーションライクなバウンド用
    @State private var leftBasketOffset: CGFloat = 0
    @State private var rightBasketOffset: CGFloat = 0
    @State private var kagoOffsets: [CGFloat] = [0, 0, 0, 0] // 千、百、十、一の位のカゴしなり用
    
    // イニシャライザで再挑戦用のターゲット数値を受け取れるように拡張
    init(level: Int, targetNumber: Int? = nil, initialLeft: Int? = nil, completionHandler: @escaping (Bool) -> Void) {
        self.level = level
        self.retryTargetNumber = targetNumber
        self.retryInitialLeft = initialLeft
        self.completionHandler = completionHandler
    }
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            StarryBackgroundView()
            
            VStack(spacing: 20) {
                // 上部ヘッダー
                HStack {
                    Button(action: {
                        completionHandler(false)
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("あわせていくつ (レベル \(level))")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Circle().fill(Color.clear).frame(width: 32)
                }
                .padding(.horizontal)
                
                if level == 4 {
                    Text("【 おだい 】 \(targetNumber) に しよう！")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(.yellow)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(20)
                } else {
                    Text("ひだりのカゴに \(initialLeft) あるよ。 あわせて \(targetNumber) にするには？")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.yellow)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(18)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                if level == 4 {
                    // レベル4: 位取りのレイアウト (4つのカゴ)
                    HStack(spacing: 12) {
                        PlaceValueBasketView(title: "せん", label: "千のくらい", count: $thousandsCount, color: .purple, offset: kagoOffsets[0]) {
                            thousandsCount = max(0, thousandsCount - 1)
                        }
                        PlaceValueBasketView(title: "ひゃく", label: "百のくらい", count: $hundredsCount, color: .blue, offset: kagoOffsets[1]) {
                            hundredsCount = max(0, hundredsCount - 1)
                        }
                        PlaceValueBasketView(title: "じゅう", label: "十のくらい", count: $tensCount, color: .green, offset: kagoOffsets[2]) {
                            tensCount = max(0, tensCount - 1)
                        }
                        PlaceValueBasketView(title: "いち", label: "一のくらい", count: $onesCount, color: .orange, offset: kagoOffsets[3]) {
                            onesCount = max(0, onesCount - 1)
                        }
                    }
                    .padding(.horizontal)
                    
                    let currentTotal = (thousandsCount * 1000) + (hundredsCount * 100) + (tensCount * 10) + onesCount
                    VStack(spacing: 4) {
                        Text("いまの かず: \(currentTotal)")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("(\(thousandsCount * 1000) + \(hundredsCount * 100) + \(tensCount * 10) + \(onesCount))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 10)
                } else {
                    // レベル1〜3: 天秤レイアウト
                    GeometryReader { geo in
                        let width = geo.size.width
                        let centerY = geo.size.height * 0.4
                        
                        ZStack {
                            Path { path in
                                path.move(to: CGPoint(x: width / 2, y: centerY))
                                path.addLine(to: CGPoint(x: width / 2, y: centerY + 120))
                            }
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            
                            let leftWeight = CGFloat(initialLeft)
                            let rightWeight = CGFloat(currentRight)
                            let angleDegrees = Double(rightWeight - leftWeight) * (level == 3 ? 0.3 : 1.5)
                            
                            ZStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: width * 0.8, height: 6)
                                
                                // 左カゴ
                                VStack(spacing: 4) {
                                    ZStack {
                                        BasketShape()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 110, height: 60)
                                            .overlay(
                                                BasketShape()
                                                    .stroke(Color.blue.opacity(0.6), lineWidth: 3)
                                            )
                                        
                                        GemGridView(count: initialLeft)
                                            .frame(width: 90, height: 50)
                                    }
                                    .offset(y: leftBasketOffset)
                                    
                                    Text("\(initialLeft)")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: -width * 0.3, y: 30)
                                
                                // 右カゴ
                                VStack(spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        BasketShape()
                                            .fill(Color.pink.opacity(0.2))
                                            .frame(width: 110, height: 60)
                                            .overlay(
                                                BasketShape()
                                                    .stroke(Color.pink.opacity(0.6), lineWidth: 3)
                                            )
                                        
                                        MixedGemView(gems: addedGems)
                                            .frame(width: 90, height: 50)
                                        
                                        if !addedGems.isEmpty {
                                            Button(action: {
                                                removeLastGem()
                                            }) {
                                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                                    .font(.system(size: 26))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.red))
                                            }
                                            .offset(x: 10, y: -10)
                                        }
                                    }
                                    .offset(y: rightBasketOffset)
                                    .onTapGesture {
                                        removeLastGem()
                                    }
                                    
                                    Text("\(currentRight)")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .offset(x: width * 0.3, y: 30)
                            }
                            .rotationEffect(.degrees(angleDegrees), anchor: .center)
                            .offset(y: -40)
                        }
                    }
                    .frame(height: 240)
                }
                
                Spacer()
                
                // ジェム投入コントロール
                VStack(spacing: 12) {
                    if level == 4 {
                        Text("いれる 位のカゴを タップするか、ジェムを いれてね")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 12) {
                            ControlButton(title: "+1000", color: .purple) { addGemToPlace(0) }
                            ControlButton(title: "+100", color: .blue) { addGemToPlace(1) }
                            ControlButton(title: "+10", color: .green) { addGemToPlace(2) }
                            ControlButton(title: "+1", color: .orange) { addGemToPlace(3) }
                        }
                        .padding(.horizontal)
                    } else {
                        Text("【ジェムをえらんで カゴにいれてね】")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 20) {
                            GemButton(value: 1, icon: "star.fill", label: "1のジェム", color: .orange) {
                                addValueGem(1)
                            }
                            
                            GemButton(value: 5, icon: "bag.fill", label: "5のふくろ", color: .pink) {
                                addValueGem(5)
                            }
                            
                            if level >= 2 {
                                GemButton(value: 10, icon: "diamond.fill", label: "10のかたまり", color: .cyan) {
                                    addValueGem(10)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(24)
                    }
                }
                .padding(.bottom, 10)
                
                Button(action: {
                    checkAnswer()
                }) {
                    Text("できた！")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            .padding(.bottom, 60)
            .onAppear {
                generateNewQuestion()
            }
            
            // 結果表示オーバーレイ
            if showResultOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(isCorrect ? .green : .red)
                    
                    Text(isCorrect ? "せいかい！" : "ざんねん！")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(isCorrect ? "すごい！ぴったりできたね！" : "もういちど チャレンジしてみよう")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showResultOverlay = false
                            generateNewQuestion()
                        }) {
                            Text("つぎの問題")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .cornerRadius(20)
                        }
                        
                        Button(action: {
                            showResultOverlay = false
                            if isCorrect {
                                completionHandler(true)
                            } else {
                                withAnimation {
                                    addedGems = []
                                    thousandsCount = 0
                                    hundredsCount = 0
                                    tensCount = 0
                                    onesCount = 0
                                }
                            }
                        }) {
                            Text(isCorrect ? "おわる" : "やりなおす")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(isCorrect ? Color.blue : Color.red)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(30)
                .background(Color(red: 0.1, green: 0.1, blue: 0.2))
                .cornerRadius(32)
                .shadow(radius: 20)
                .padding(.horizontal, 30)
            }
        }
    }
    
    // 【修正】初回読み込み時かつ再挑戦用お題がある場合は、それを固定でセットする
    private func generateNewQuestion() {
        if isFirstLoad && retryTargetNumber != nil {
            isFirstLoad = false
            self.targetNumber = retryTargetNumber!
            if level == 4 {
                thousandsCount = 0
                hundredsCount = 0
                tensCount = 0
                onesCount = 0
            } else {
                // 左皿の初期値を決定論的に復元（同じ問題の再現）
                let backupLeft = retryInitialLeft ?? (retryTargetNumber! * 4 / 10)
                // 1未満にならないよう保護
                self.initialLeft = max(1, min(backupLeft, retryTargetNumber! - 1))
                self.addedGems = []
            }
            return
        }
        
        // それ以外はランダムに新規作成
        switch level {
        case 1:
            targetNumber = Int.random(in: 4...10)
            initialLeft = Int.random(in: 1..<targetNumber)
            addedGems = []
        case 2:
            initialLeft = Int.random(in: 6...9)
            let needed = Int.random(in: 4...9)
            targetNumber = initialLeft + needed
            addedGems = []
        case 3:
            let tens = Int.random(in: 2...8) * 10
            let targetOnes = Int.random(in: 1...9)
            targetNumber = tens + targetOnes
            initialLeft = (Int.random(in: 1..<tens/10) * 10) + Int.random(in: 0...targetOnes)
            addedGems = []
        case 4:
            targetNumber = Int.random(in: 1000...9999)
            thousandsCount = 0
            hundredsCount = 0
            tensCount = 0
            onesCount = 0
        default:
            break
        }
    }
    
    private func addValueGem(_ value: Int) {
        if currentRight + value <= targetNumber - initialLeft + 15 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                addedGems.append(value)
                rightBasketOffset = 10
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring()) { rightBasketOffset = 0 }
                }
            }
            HapticManager.shared.playCorrectHaptic()
        }
    }
    
    private func removeLastGem() {
        if !addedGems.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                _ = addedGems.popLast()
                rightBasketOffset = -10
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring()) { rightBasketOffset = 0 }
                }
            }
            HapticManager.shared.playCorrectHaptic()
        }
    }
    
    private func addGemToPlace(_ index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            switch index {
            case 0:
                if thousandsCount < 9 { thousandsCount += 1 }
            case 1:
                if hundredsCount < 9 { hundredsCount += 1 }
            case 2:
                if tensCount < 9 { tensCount += 1 }
            case 3:
                if onesCount < 9 { onesCount += 1 }
            default:
                break
            }
            kagoOffsets[index] = 8
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) { kagoOffsets[index] = 0 }
            }
        }
        HapticManager.shared.playCorrectHaptic()
    }
    
    private func checkAnswer() {
        let userTotal: Int
        if level == 4 {
            userTotal = (thousandsCount * 1000) + (hundredsCount * 100) + (tensCount * 10) + onesCount
            isCorrect = userTotal == targetNumber
        } else {
            userTotal = initialLeft + currentRight
            isCorrect = userTotal == targetNumber
        }
        
        if isCorrect {
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
        } else {
            SoundManager.shared.playIncorrect()
            HapticManager.shared.playIncorrectHaptic()
        }
        
        HistoryManager.shared.addRecord(
            mode: .combine,
            digits: level == 4 ? 4 : (level == 3 ? 2 : 1),
            questionNumber: targetNumber,
            isCorrect: isCorrect,
            userResponse: "\(userTotal)"
        )
        
        showResultOverlay = true
    }
}

// MARK: - Place Value Basket View
struct PlaceValueBasketView: View {
    let title: String
    let label: String
    @Binding var count: Int
    let color: Color
    let offset: CGFloat
    let tapAction: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(color)
            
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(color.opacity(0.15))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(color.opacity(0.5), lineWidth: 2)
                    )
                
                let items = Array(0..<count)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                    ForEach(items, id: \.self) { _ in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [color.opacity(0.8), color],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 8
                                )
                            )
                            .frame(width: 12, height: 12)
                            .shadow(color: color.opacity(0.4), radius: 2)
                    }
                }
                .padding(8)
                
                if count > 0 {
                    Button(action: tapAction) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .offset(y: offset)
            
            Text("\(count)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

// MARK: - Gem Button
struct GemButton: View {
    let value: Int
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text("+\(value)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 80)
        }
    }
}

// MARK: - Mixed Gem View
struct MixedGemView: View {
    let gems: [Int]
    
    var body: some View {
        let sortedGems = gems.sorted(by: >)
        
        HStack(spacing: 4) {
            ForEach(0..<sortedGems.count, id: \.self) { idx in
                let val = sortedGems[idx]
                
                if val == 10 {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(0.5), radius: 3)
                } else if val == 5 {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.pink)
                        .shadow(color: .pink.opacity(0.5), radius: 2)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Basket Shape
struct BasketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - 20, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height * 0.8)
        )
        path.addLine(to: CGPoint(x: 20, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: 0),
            control: CGPoint(x: 0, y: rect.height * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Gem Grid View (左カゴ用)
struct GemGridView: View {
    let count: Int
    
    var body: some View {
        let columns = count > 5 ? 4 : count
        let items = Array(0..<count)
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 8, maximum: 14), spacing: 2), count: columns == 0 ? 1 : columns),
            spacing: 2
        ) {
            ForEach(items, id: \.self) { _ in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow, .orange],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 10, height: 10)
                    .shadow(color: .orange.opacity(0.3), radius: 2)
            }
        }
        .padding(4)
    }
}
