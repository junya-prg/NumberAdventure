import SwiftUI

struct DotToDotModeView: View {
    let startNum: Int // 開始数値 (例: 1, 7, 95, 995)
    let dotCount: Int // ドット数 (例: 10, 6, 8)
    let completionHandler: (Bool) -> Void
    
    // 現在の問題の状態 (連続プレイ用にState化)
    @State private var currentStartNum: Int
    @State private var connectedPoints: [Int] = []
    @State private var currentDragPoint: CGPoint? = nil
    @State private var showCompleteAnimation = false
    @State private var showCompleteOverlay = false
    @State private var sparks: [Spark] = []
    
    // ランダム配置されたドットの座標
    @State private var dotPositions: [CGPoint] = []
    
    struct Spark: Identifiable {
        let id = UUID()
        var position: CGPoint
        var color: Color
        var scale: CGFloat
        var opacity: Double
    }
    
    init(startNum: Int, dotCount: Int, completionHandler: @escaping (Bool) -> Void) {
        self.startNum = startNum
        self.dotCount = dotCount
        self.completionHandler = completionHandler
        _currentStartNum = State(initialValue: startNum)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack(alignment: .top) {
                // 1. 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.12),
                        Color(red: 0.08, green: 0.1, blue: 0.22)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 2. キャンバス (画面全体に広げることで、ドットの座標系を geometry と 1対1 に一致させる)
                ZStack {
                    // 線
                    Path { path in
                        guard !connectedPoints.isEmpty && dotPositions.count == dotCount else { return }
                        path.move(to: dotPositions[connectedPoints[0]])
                        for i in 1..<connectedPoints.count {
                            path.addLine(to: dotPositions[connectedPoints[i]])
                        }
                        
                        if let currentDrag = currentDragPoint, let lastIdx = connectedPoints.last {
                            path.move(to: dotPositions[lastIdx])
                            path.addLine(to: currentDrag)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: isLandscape ? 6 : 8, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 10)
                    
                    // 完成時のダイナミックな完成数表示
                    if showCompleteAnimation {
                        VStack(spacing: isLandscape ? 8 : 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.15))
                                    .frame(width: isLandscape ? 160 : 240, height: isLandscape ? 160 : 240)
                                    .blur(radius: 20)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: isLandscape ? 90 : 140))
                                    .foregroundColor(.yellow)
                                    .opacity(0.8)
                                
                                Text("\(currentStartNum + dotCount - 1)")
                                    .font(.system(size: isLandscape ? 50 : 80, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .orange, radius: 15)
                            }
                            .scaleEffect(showCompleteOverlay ? 1.25 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showCompleteOverlay)
                            
                            Text("クリア！")
                                .font(.system(isLandscape ? .title2 : .title, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(.yellow)
                                .shadow(radius: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // ドットの描画
                    if !showCompleteAnimation && dotPositions.count == dotCount {
                        ForEach(0..<dotCount, id: \.self) { index in
                            let isConnected = connectedPoints.contains(index)
                            let displayValue = currentStartNum + index
                            
                            ZStack {
                                Circle()
                                    .fill(isConnected ? Color.orange : Color.white.opacity(0.2))
                                    .frame(width: isLandscape ? 38 : 46, height: isLandscape ? 38 : 46)
                                    .overlay(
                                        Circle()
                                            .stroke(isConnected ? Color.yellow : Color.white.opacity(0.4), lineWidth: 2)
                                    )
                                    .shadow(color: isConnected ? .orange : .clear, radius: 8)
                                
                                Text("\(displayValue)")
                                    .font(.system(isLandscape ? .body : .headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .position(dotPositions[index])
                        }
                    }
                    
                    // パーティクル
                    ForEach(sparks) { spark in
                        Circle()
                            .fill(spark.color)
                            .frame(width: 8 * spark.scale, height: 8 * spark.scale)
                            .position(spark.position)
                            .opacity(spark.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle()) // 透明領域でもドラッグを検知させるため
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(at: value.location, points: dotPositions)
                        }
                        .onEnded { _ in
                            currentDragPoint = nil
                        }
                )
                .ignoresSafeArea()
                
                // 3. UIオーバーレイ
                VStack(spacing: isLandscape ? 6 : 12) {
                    // ヘッダー
                    HStack {
                        Button(action: {
                            completionHandler(false)
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: isLandscape ? 26 : 32))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("てんつなぎ (\(currentStartNum)〜\(currentStartNum + dotCount - 1))")
                            .font(.system(isLandscape ? .title3 : .title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Circle().fill(Color.clear).frame(width: isLandscape ? 26 : 32)
                    }
                    .padding(.horizontal)
                    
                    Text("\(currentStartNum) から じゅんばんに せんを つないでね")
                        .font(.system(isLandscape ? .caption : .subheadline, design: .rounded))
                        .foregroundColor(.yellow)
                        .padding(.vertical, isLandscape ? 4 : 6)
                        .padding(.horizontal, isLandscape ? 10 : 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                    
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top + 8 : 16)
                .allowsHitTesting(true)
                .ignoresSafeArea()
            }
            .onAppear {
                generatePositions(in: geometry)
                if connectedPoints.isEmpty {
                    connectedPoints.append(0)
                }
            }
            .alert(isPresented: $showCompleteOverlay) {
                Alert(
                    title: Text("クリア！"),
                    message: Text("\(currentStartNum)から\(currentStartNum + dotCount - 1)まで、正しくつなげられたね！"),
                    primaryButton: .default(Text("つぎの問題")) {
                        advanceToNextQuestion(in: geometry)
                    },
                    secondaryButton: .cancel(Text("おわる")) {
                        completionHandler(true)
                    }
                )
            }
        }
    }
    
    private func generatePositions(in geometry: GeometryProxy) {
        let size = geometry.size
        let insets = geometry.safeAreaInsets
        let isLandscape = size.width > size.height
        
        // 画面端の丸角やノッチ、ホームインジケータを避けるため、ドットの半径（約23pt）も加味した十分な安全余白を設定します
        let paddingLeft = insets.leading > 0 ? insets.leading + (isLandscape ? 40 : 30) : (isLandscape ? 45 : 30)
        let paddingRight = insets.trailing > 0 ? insets.trailing + (isLandscape ? 40 : 30) : (isLandscape ? 45 : 30)
        let paddingTop = insets.top > 0 ? insets.top + (isLandscape ? 55 : 95) : (isLandscape ? 70 : 110) // ヘッダー・説明UIとの被り防止
        let paddingBottom = insets.bottom > 0 ? insets.bottom + (isLandscape ? 40 : 45) : (isLandscape ? 45 : 55) // 下部ホームバー・丸角での切れ防止
        
        let usableWidth = size.width - paddingLeft - paddingRight
        let usableHeight = size.height - paddingTop - paddingBottom
        
        let rows = isLandscape ? 3 : 4
        let cols = isLandscape ? 4 : 3
        var cells = Array(0..<(rows * cols))
        cells.shuffle()
        
        let cellWidth = usableWidth / CGFloat(cols)
        let cellHeight = usableHeight / CGFloat(rows)
        
        var newPositions: [CGPoint] = []
        for index in 0..<min(dotCount, cells.count) {
            let cellIdx = cells[index]
            let r = cellIdx / cols
            let c = cellIdx % cols
            
            // ドットがセルからはみ出して隣や画面外へ行くのを防ぐため、ブレ幅（jitter）を20%に抑える
            let maxJitterX = cellWidth * 0.20
            let maxJitterY = cellHeight * 0.20
            let jitterX = CGFloat.random(in: -maxJitterX...maxJitterX)
            let jitterY = CGFloat.random(in: -maxJitterY...maxJitterY)
            
            let x = paddingLeft + (CGFloat(c) + 0.5) * cellWidth + jitterX
            let y = paddingTop + (CGFloat(r) + 0.5) * cellHeight + jitterY
            newPositions.append(CGPoint(x: x, y: y))
        }
        
        self.dotPositions = newPositions
    }
    
    private func handleDrag(at location: CGPoint, points: [CGPoint]) {
        guard !showCompleteAnimation && points.count == dotCount else { return }
        
        currentDragPoint = location
        
        let nextIndex = connectedPoints.count
        guard nextIndex < points.count else { return }
        
        let targetPoint = points[nextIndex]
        let distance = sqrt(pow(location.x - targetPoint.x, 2) + pow(location.y - targetPoint.y, 2))
        
        // ターゲットドットの判定範囲 (判定しやすく大きめの 32pt)
        if distance < 32 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                connectedPoints.append(nextIndex)
                currentDragPoint = nil
            }
            
            HapticManager.shared.playCorrectHaptic()
            generateSparks(at: targetPoint)
            
            if connectedPoints.count == points.count {
                // 記録に登録 (てんつなぎ: レベル名を保存)
                let levelName: String
                if currentStartNum >= 990 { levelName = "1000のかべ" }
                else if currentStartNum >= 90 { levelName = "100のかべ" }
                else if currentStartNum >= 20 { levelName = "十の位のかべ" }
                else if currentStartNum >= 6 { levelName = "10のかべ" }
                else { levelName = "1けたのかべ" }
                
                HistoryManager.shared.addRecord(
                    mode: .dotToDot,
                    digits: currentStartNum >= 990 ? 4 : (currentStartNum >= 90 ? 3 : (currentStartNum >= 20 ? 2 : 1)),
                    questionNumber: currentStartNum + dotCount - 1,
                    isCorrect: true,
                    userResponse: levelName
                )
                
                withAnimation(.easeInOut(duration: 0.8)) {
                    showCompleteAnimation = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showCompleteOverlay = true
                }
            }
        }
    }
    
    private func generateSparks(at point: CGPoint) {
        for _ in 0..<15 {
            let spark = Spark(
                position: point,
                color: [.yellow, .white, .orange, .pink].randomElement()!,
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0
            )
            sparks.append(spark)
        }
        
        for i in 0..<sparks.count {
            withAnimation(.easeOut(duration: 0.6)) {
                sparks[i].position.x += CGFloat.random(in: -60...60)
                sparks[i].position.y += CGFloat.random(in: -60...60)
                sparks[i].opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            sparks.removeAll()
        }
    }
    
    // 【連続プレイ】ランダム値で次のまたぎ問題を生成
    private func advanceToNextQuestion(in geometry: GeometryProxy) {
        let nextStart: Int
        if startNum >= 990 { // 1000のかべ
            nextStart = Int.random(in: 993...999)
        } else if startNum >= 90 { // 100のかべ
            let starts = [95, 137, 236]
            nextStart = starts.randomElement()!
        } else if startNum >= 20 { // 十の位のかべ
            let starts = [26, 36, 46, 55, 66, 76, 85]
            nextStart = starts.randomElement()!
        } else if startNum >= 6 { // 10のかべ
            nextStart = Int.random(in: 6...9)
        } else { // かんたん
            nextStart = Int.random(in: 1...5)
        }
        
        withAnimation {
            currentStartNum = nextStart
            connectedPoints = [0]
            showCompleteAnimation = false
            showCompleteOverlay = false
            currentDragPoint = nil
            sparks = []
            generatePositions(in: geometry) // 新しい座標を再生成
        }
    }
}
