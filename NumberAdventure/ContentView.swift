import SwiftUI
import PencilKit
import StoreKit
import Combine

// MARK: - Color Extensions for Light/Dark Mode
extension Color {
    static func appBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.10, blue: 0.08) : Color(red: 0.98, green: 0.97, blue: 0.93)
    }
    
    static func appText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.92, green: 0.89, blue: 0.84) : Color(red: 0.3, green: 0.25, blue: 0.2)
    }
    
    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.22, green: 0.20, blue: 0.17) : Color.white
    }
}

// MARK: - Root Content View
struct ContentView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @State private var selectedDigits: Int = 3
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ReadModeView(starsCount: $historyManager.starsCount, selectedDigits: $selectedDigits, isActive: selectedTab == 0)
                .tabItem {
                    Label("よむ", systemImage: "mic.fill")
                }
                .tag(0)
            
            WriteModeView(starsCount: $historyManager.starsCount, selectedDigits: $selectedDigits, isActive: selectedTab == 1)
                .tabItem {
                    Label("かく", systemImage: "pencil.and.outline")
                }
                .tag(1)
            
            PlayView()
                .tabItem {
                    Label("あそぶ", systemImage: "gamecontroller.fill")
                }
                .tag(2)
            
            HistoryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("きろく", systemImage: "calendar")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("せってい", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.95, green: 0.55, blue: 0.2)) // テーマのオレンジ色
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - よむモード (Read Mode View)
struct ReadModeView: View {
    @Binding var starsCount: Int
    @Binding var selectedDigits: Int
    let isActive: Bool
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var historyManager = HistoryManager.shared
    
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    
    @State private var currentNumber: Int = 123
    
    enum AnswerStatus {
        case none
        case correct
        case incorrect
    }
    @State private var answerStatus: AnswerStatus = .none
    @State private var showResultOverlay: Bool = false
    
    @State private var animateStar: Bool = false
    @State private var pulseMic: Bool = false
    @State private var isCancelled: Bool = false
    @State private var isAnimatingRipple: Bool = false
    @State private var isApplyingRetry: Bool = false
    
    var body: some View {
        ZStack {
            Color.appBackground(for: colorScheme)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                if isLandscape {
                    landscapeLayout(size: geometry.size)
                } else {
                    portraitLayout()
                }
            }
            .padding(.vertical, 8)
            
            if showResultOverlay {
                resultOverlayView()
            }
        }
        .onAppear {
            guard isActive else { return }
            if let request = historyManager.retryRequest, request.mode == .read {
                applyRetryRequest(request)
            } else {
                generateNewNumber()
            }
        }
        .onChange(of: selectedDigits) { _ in
            if isActive && !isApplyingRetry {
                generateNewNumber()
            }
        }
        .onChange(of: historyManager.retryRequest) { request in
            if isActive, let request = request, request.mode == .read {
                applyRetryRequest(request)
            }
        }
        .onChange(of: speechRecognizer.isRecording) { isRecording in
            if !isRecording {
                if isCancelled {
                    isCancelled = false
                } else if !speechRecognizer.transcript.isEmpty {
                    checkAnswer()
                }
            }
            
            withAnimation(isRecording ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default) {
                pulseMic = isRecording
            }
        }
    }
    
    // 縦向きレイアウト
    @ViewBuilder
    private func portraitLayout() -> some View {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let fontSize: CGFloat
        let spacing: CGFloat
        
        switch selectedDigits {
        case 1:
            cardWidth = 150
            cardHeight = 210
            fontSize = 120
            spacing = 16
        case 2:
            cardWidth = 125
            cardHeight = 175
            fontSize = 100
            spacing = 12
        case 3:
            cardWidth = 100
            cardHeight = 140
            fontSize = 80
            spacing = 10
        default: // 4
            cardWidth = 78
            cardHeight = 110
            fontSize = 62
            spacing = 8
        }
        
        return VStack(spacing: 16) {
            // 上部ヘッダー（星メーター）
            HStack {
                Text("すうじアドベンチャー")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.appText(for: colorScheme))
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .scaleEffect(animateStar ? 1.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animateStar)
                    Text("\(starsCount)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cardBackground(for: colorScheme).opacity(0.8))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal)
            
            // 桁数選択
            HStack(spacing: 12) {
                ForEach([1, 2, 3, 4], id: \.self) { digit in
                    Button(action: {
                        selectedDigits = digit
                    }) {
                        Text("\(digit)けた")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(selectedDigits == digit ? .white : Color.appText(for: colorScheme).opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDigits == digit ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.cardBackground(for: colorScheme))
                            .cornerRadius(15)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.top, 4)
            
            Spacer(minLength: 8)
            
            // 数字表示エリア
            VStack(spacing: 12) {
                HStack(spacing: spacing) {
                    if selectedDigits >= 4 {
                        digitCard(
                            value: String(currentNumber / 1000),
                            label: "せん",
                            color: Color(red: 0.6, green: 0.4, blue: 0.8),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    if selectedDigits >= 3 {
                        let hundreds = (currentNumber % 1000) / 100
                        digitCard(
                            value: String(hundreds),
                            label: "ひゃく",
                            color: Color(red: 0.25, green: 0.55, blue: 0.85),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    if selectedDigits >= 2 {
                        let tens = (currentNumber % 100) / 10
                        digitCard(
                            value: String(tens),
                            label: "じゅう",
                            color: Color(red: 0.35, green: 0.65, blue: 0.35),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    digitCard(
                        value: String(currentNumber % 10),
                        label: "いち",
                        color: Color(red: 0.9, green: 0.4, blue: 0.35),
                        width: cardWidth,
                        height: cardHeight,
                        fontSize: fontSize
                    )
                }
                .padding(.horizontal)
                
                if answerStatus == .incorrect {
                    VStack(spacing: 8) {
                        Text(JapaneseNumberFormatter.toFuriganaSpaced(currentNumber))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.3))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(colorScheme == .dark ? Color(red: 0.35, green: 0.18, blue: 0.15) : Color(red: 1.0, green: 0.92, blue: 0.92))
                            .cornerRadius(15)
                            .transition(.opacity.combined(with: .scale))
                        
                        Button(action: {
                            playCorrectVoice()
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("もういちど きく")
                            }
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.9, green: 0.4, blue: 0.35))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // 音声認識の音声吹き出しプレビュー
            VStack {
                if speechRecognizer.isRecording {
                    VStack(spacing: 4) {
                        Text("きいているよ...👂")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.gray)
                        Text(speechRecognizer.transcript.isEmpty ? "こえをだしてね" : speechRecognizer.transcript)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(Color.appText(for: colorScheme))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.cardBackground(for: colorScheme))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: speechRecognizer.isRecording ? 80 : 0)
            
            // コントロールボタン
            controlButtonsView()
                .frame(height: 140)
            
            Spacer(minLength: 8)
        }
    }
    
    // 横向きレイアウト
    @ViewBuilder
    private func landscapeLayout(size: CGSize) -> some View {
        let leftWidth = size.width * 0.58
        let maxAvailableHeight = size.height - 80
        let maxCardWidthBasedOnHeight = maxAvailableHeight / 1.4
        
        let spacingOffset = CGFloat(selectedDigits - 1) * 12
        let maxCardWidthBasedOnWidth = (leftWidth - spacingOffset) / CGFloat(selectedDigits)
        
        let cardWidth = min(min(maxCardWidthBasedOnWidth, 150), maxCardWidthBasedOnHeight)
        let cardHeight = cardWidth * 1.4
        let fontSize = cardWidth * (88.0 / 105.0)
        
        return HStack(spacing: 24) {
            // 左側半分: 数字表示エリア
            VStack(spacing: 12) {
                Spacer()
                
                HStack(spacing: 12) {
                    if selectedDigits >= 4 {
                        digitCard(
                            value: String(currentNumber / 1000),
                            label: "せん",
                            color: Color(red: 0.6, green: 0.4, blue: 0.8),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    if selectedDigits >= 3 {
                        let hundreds = (currentNumber % 1000) / 100
                        digitCard(
                            value: String(hundreds),
                            label: "ひゃく",
                            color: Color(red: 0.25, green: 0.55, blue: 0.85),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    if selectedDigits >= 2 {
                        let tens = (currentNumber % 100) / 10
                        digitCard(
                            value: String(tens),
                            label: "じゅう",
                            color: Color(red: 0.35, green: 0.65, blue: 0.35),
                            width: cardWidth,
                            height: cardHeight,
                            fontSize: fontSize
                        )
                    }
                    digitCard(
                        value: String(currentNumber % 10),
                        label: "いち",
                        color: Color(red: 0.9, green: 0.4, blue: 0.35),
                        width: cardWidth,
                        height: cardHeight,
                        fontSize: fontSize
                    )
                }
                
                // ふりがな表示
                if answerStatus == .incorrect {
                    VStack(spacing: 4) {
                        Text(JapaneseNumberFormatter.toFuriganaSpaced(currentNumber))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(colorScheme == .dark ? Color(red: 0.35, green: 0.18, blue: 0.15) : Color(red: 1.0, green: 0.92, blue: 0.92))
                            .cornerRadius(10)
                        
                        Button(action: {
                            playCorrectVoice()
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("もういちど きく")
                            }
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.9, green: 0.4, blue: 0.35))
                            .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(width: leftWidth)
            
            Divider()
                .background(Color.appText(for: colorScheme).opacity(0.15))
                .padding(.vertical, 8)
            
            // 右側半分: ヘッダー、設定、吹き出しプレビュー、コントロール
            VStack(spacing: 12) {
                HStack {
                    Text("すうじアドベンチャー")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.body)
                            .scaleEffect(animateStar ? 1.5 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animateStar)
                        Text("\(starsCount)")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground(for: colorScheme).opacity(0.8))
                    .cornerRadius(15)
                }
                
                // 桁数選択（右側に移動）
                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4], id: \.self) { digit in
                        Button(action: {
                            selectedDigits = digit
                        }) {
                            Text("\(digit)けた")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(selectedDigits == digit ? .white : Color.appText(for: colorScheme).opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedDigits == digit ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.cardBackground(for: colorScheme))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.top, 4)
                
                Spacer()
                
                // 音声認識吹き出しプレビュー
                VStack {
                    if speechRecognizer.isRecording {
                        VStack(spacing: 4) {
                            Text("きいているよ...👂")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            Text(speechRecognizer.transcript.isEmpty ? "こえをだしてね" : speechRecognizer.transcript)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(Color.appText(for: colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.cardBackground(for: colorScheme))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                        }
                    }
                }
                .frame(height: speechRecognizer.isRecording ? 70 : 0)
                
                Spacer()
                
                // コントロールボタン
                controlButtonsView()
                    .frame(height: 110)
                
                Spacer()
            }
            .frame(width: size.width * 0.36)
        }
        .padding(.horizontal)
    }
    
    // コントロールボタン群
    @ViewBuilder
    private func controlButtonsView() -> some View {
        if answerStatus == .none {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    if speechRecognizer.isRecording {
                        miniWaveform()
                    } else {
                        Spacer().frame(width: 25)
                    }
                    
                    ZStack {
                        if !speechRecognizer.isRecording {
                            Circle()
                                .stroke(Color(red: 0.95, green: 0.55, blue: 0.2).opacity(0.4), lineWidth: 4)
                                .frame(width: 76, height: 76)
                                .scaleEffect(isAnimatingRipple ? 1.4 : 1.0)
                                .opacity(isAnimatingRipple ? 0.0 : 1.0)
                                .onAppear {
                                    isAnimatingRipple = false
                                    withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                        isAnimatingRipple = true
                                    }
                                }
                                .id("ripple-wait-\(speechRecognizer.isRecording)")
                        } else {
                            Circle()
                                .fill(Color.red.opacity(0.25))
                                .frame(width: 76, height: 76)
                                .scaleEffect(isAnimatingRipple ? 1.3 : 1.0)
                                .onAppear {
                                    isAnimatingRipple = false
                                    withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                        isAnimatingRipple = true
                                    }
                                }
                                .id("ripple-recording-\(speechRecognizer.isRecording)")
                        }
                        
                        Button(action: {
                            toggleRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.red : Color(red: 0.95, green: 0.55, blue: 0.2))
                                    .frame(width: 76, height: 76)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if speechRecognizer.isRecording {
                        miniWaveform()
                    } else {
                        Spacer().frame(width: 25)
                    }
                }
                
                if speechRecognizer.isRecording {
                    Button(action: {
                        cancelRecording()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("やりなおす")
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.3))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(colorScheme == .dark ? Color(red: 0.25, green: 0.18, blue: 0.15) : Color(red: 0.95, green: 0.9, blue: 0.85))
                        .cornerRadius(12)
                    }
                    .transition(.opacity.combined(with: .scale))
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
        } else {
            HStack(spacing: 24) {
                if answerStatus == .incorrect {
                    Button(action: {
                        resetAnswer()
                    }) {
                        Text("もういちど")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                            .frame(width: 130, height: 50)
                            .background(Color.cardBackground(for: colorScheme))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.appText(for: colorScheme).opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                
                Button(action: {
                    generateNewNumber(startRecording: true)
                }) {
                    Text("つぎへ")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(Color(red: 0.35, green: 0.7, blue: 0.35))
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                }
            }
        }
    }
    
    @ViewBuilder
    private func miniWaveform() -> some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 3, height: speechRecognizer.isRecording ? CGFloat.random(in: 12...32) : 6)
                    .animation(
                        Animation.linear(duration: 0.25)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.06),
                        value: speechRecognizer.isRecording
                    )
            }
        }
        .frame(width: 25)
    }
    
    private func digitCard(value: String, label: String, color: Color, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: width, height: height)
                .background(Color.cardBackground(for: colorScheme))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.3), lineWidth: 3)
                )
            
            Text(label)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(color.opacity(0.8))
        }
    }
    
    private func resultOverlayView() -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if answerStatus == .correct {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.35))
                        
                        Text("はなまる！")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.35))
                        
                        Text("せいかい！すばらしい！")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(30)
                    .shadow(radius: 10)
                } else if answerStatus == .incorrect {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        
                        Text("おしい！")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        
                        Text("もういちど チャレンジしてみよう")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(30)
                    .shadow(radius: 10)
                }
            }
        }
    }
    
    private func generateNewNumber(startRecording: Bool = false) {
        speechSynthesizer.stop()
        speechRecognizer.reset()
        answerStatus = .none
        showResultOverlay = false
        
        switch selectedDigits {
        case 1:
            currentNumber = Int.random(in: 1...9)
        case 2:
            currentNumber = Int.random(in: 10...99)
        case 3:
            currentNumber = Int.random(in: 100...999)
        default:
            currentNumber = Int.random(in: 1000...9999)
        }
        
        if startRecording {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            speechRecognizer.startTranscribing()
        }
    }
    
    private func resetAnswer() {
        speechSynthesizer.stop()
        speechRecognizer.reset()
        answerStatus = .none
        showResultOverlay = false
        
        // 「もういちど」ボタン押下時に自動で録音を開始
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        speechRecognizer.startTranscribing()
    }
    
    private func checkAnswer() {
        let expectedReading = JapaneseNumberFormatter.toJapaneseReading(currentNumber)
        let cleanTranscript = cleanJapaneseReading(speechRecognizer.transcript)
        
        let isCorrect = cleanTranscript == expectedReading || speechRecognizer.transcript.contains(expectedReading) || cleanTranscript.contains(expectedReading)
        
        // 履歴を保存（正解時はここで starsCount が加算される）
        historyManager.addRecord(
            mode: .read,
            digits: selectedDigits,
            questionNumber: currentNumber,
            isCorrect: isCorrect,
            userResponse: speechRecognizer.transcript
        )
        
        if isCorrect {
            answerStatus = .correct
            animateStar = true
            
            HapticManager.shared.playCorrectHaptic()
            SoundManager.shared.playCorrect()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animateStar = false
            }
        } else {
            answerStatus = .incorrect
            
            HapticManager.shared.playIncorrectHaptic()
            SoundManager.shared.playIncorrect()
            
            playCorrectVoice()
        }
        
        showResultOverlay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showResultOverlay = false
            }
            
            if isCorrect {
                generateNewNumber(startRecording: true)
            }
        }
    }
    
    private func applyRetryRequest(_ request: RetryRequest) {
        guard !self.isApplyingRetry else { return }
        self.isApplyingRetry = true
        
        self.selectedDigits = request.digits
        self.currentNumber = request.number
        self.answerStatus = .none
        self.showResultOverlay = false
        
        speechSynthesizer.stop()
        speechRecognizer.reset()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            speechRecognizer.startTranscribing()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isApplyingRetry = false
            if historyManager.retryRequest == request {
                historyManager.retryRequest = nil
            }
        }
    }
    
    private func playCorrectVoice() {
        let expectedReading = JapaneseNumberFormatter.toJapaneseReading(currentNumber)
        speechSynthesizer.speak("せいかいは、\(expectedReading)、です")
    }
    
    private func cleanJapaneseReading(_ rawText: String) -> String {
        var cleaned = rawText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "、", with: "")
            .replacingOccurrences(of: "。", with: "")
            .lowercased()
        
        if let num = Int(cleaned), num == currentNumber {
            return JapaneseNumberFormatter.toJapaneseReading(currentNumber)
        }
        
        // 漢字数字の濁音・半濁音・促音のゆらぎ吸収
        let specialKanjiReadings = [
            "三千": "さんぜん",
            "八千": "はっせん",
            "三百": "さんびゃく",
            "六百": "ろっぴゃく",
            "八百": "はっぴゃく"
        ]
        for (kanji, reading) in specialKanjiReadings {
            cleaned = cleaned.replacingOccurrences(of: kanji, with: reading)
        }
        
        let kanjiNums = [
            "千": "せん", "百": "ひゃく", "十": "じゅう", "一": "いち", "二": "に", "三": "さん",
            "四": "よん", "五": "ご", "六": "ろく", "七": "なな", "八": "はち", "九": "きゅう"
        ]
        for (kanji, hiragana) in kanjiNums {
            cleaned = cleaned.replacingOccurrences(of: kanji, with: hiragana)
        }
        
        return cleaned
    }
    
    private func toggleRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if speechRecognizer.isRecording {
            speechRecognizer.stopTranscribing()
        } else {
            speechSynthesizer.stop()
            speechRecognizer.startTranscribing()
        }
    }
    
    private func cancelRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isCancelled = true
        speechRecognizer.stopTranscribing()
        speechRecognizer.reset()
        answerStatus = .none
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isCancelled = false
        }
    }
}

// MARK: - かくモード (Write Mode View)
struct WriteModeView: View {
    @Binding var starsCount: Int
    @Binding var selectedDigits: Int
    let isActive: Bool
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var historyManager = HistoryManager.shared
    
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    
    @State private var currentNumber: Int = 123
    @State private var thousandsDrawing = PKDrawing()
    @State private var hundredsDrawing = PKDrawing()
    @State private var tensDrawing = PKDrawing()
    @State private var onesDrawing = PKDrawing()
    
    @State private var activePosition: DigitPosition = .ones
    @State private var autoAdvanceTask: Task<Void, Never>? = nil
    
    @State private var isRecognizing: Bool = false
    @State private var clearTrigger: Bool = false
    
    enum AnswerStatus {
        case none
        case correct
        case incorrect
    }
    @State private var answerStatus: AnswerStatus = .none
    @State private var showResultOverlay: Bool = false
    @State private var animateStar: Bool = false
    @State private var isApplyingRetry: Bool = false
    
    enum DigitPosition: Int, CaseIterable, Comparable {
        case thousands = 3
        case hundreds = 2
        case tens = 1
        case ones = 0
        
        static func < (lhs: DigitPosition, rhs: DigitPosition) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    private var activeDrawingBinding: Binding<PKDrawing> {
        switch activePosition {
        case .thousands: return $thousandsDrawing
        case .hundreds: return $hundredsDrawing
        case .tens: return $tensDrawing
        case .ones: return $onesDrawing
        }
    }
    
    var body: some View {
        ZStack {
            Color.appBackground(for: colorScheme)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                if isLandscape {
                    landscapeLayout(size: geometry.size)
                } else {
                    portraitLayout()
                }
            }
            .padding(.vertical, 8)
            
            if showResultOverlay {
                resultOverlayView()
            }
        }
        .onAppear {
            guard isActive else { return }
            if let request = historyManager.retryRequest, request.mode == .write {
                applyRetryRequest(request)
            } else {
                generateNewNumber()
            }
        }
        .onChange(of: selectedDigits) { _ in
            if isActive && !isApplyingRetry {
                generateNewNumber()
            }
        }
        .onChange(of: historyManager.retryRequest) { request in
            if isActive, let request = request, request.mode == .write {
                applyRetryRequest(request)
            }
        }
        .onChange(of: thousandsDrawing) { drawing in
            if activePosition == .thousands {
                triggerAutoAdvanceTimer(for: drawing)
            }
        }
        .onChange(of: hundredsDrawing) { drawing in
            if activePosition == .hundreds {
                triggerAutoAdvanceTimer(for: drawing)
            }
        }
        .onChange(of: tensDrawing) { drawing in
            if activePosition == .tens {
                triggerAutoAdvanceTimer(for: drawing)
            }
        }
        .onChange(of: onesDrawing) { drawing in
            if activePosition == .ones {
                triggerAutoAdvanceTimer(for: drawing)
            }
        }
    }
    
    // 縦向きレイアウト
    @ViewBuilder
    private func portraitLayout() -> some View {
        VStack(spacing: 12) {
            // 上部ヘッダー（星メーター）
            HStack {
                Text("すうじアドベンチャー")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.appText(for: colorScheme))
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .scaleEffect(animateStar ? 1.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animateStar)
                    Text("\(starsCount)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cardBackground(for: colorScheme).opacity(0.8))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal)
            
            // 桁数選択
            HStack(spacing: 10) {
                ForEach([1, 2, 3, 4], id: \.self) { digit in
                    Button(action: {
                        selectedDigits = digit
                    }) {
                        Text("\(digit)けた")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(selectedDigits == digit ? .white : Color.appText(for: colorScheme).opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDigits == digit ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.cardBackground(for: colorScheme))
                            .cornerRadius(15)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.top, 4)
            
            // おとをきくボタン
            Button(action: {
                playQuestionVoice()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.2))
                    Text("おとをきく")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(Color.cardBackground(for: colorScheme))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3)
            }
            .padding(.top, 4)
            
            // 上部：プレビューミニカード
            HStack(spacing: 8) {
                if selectedDigits >= 4 {
                    previewCard(drawing: thousandsDrawing, position: .thousands, label: "せん", color: Color(red: 0.6, green: 0.4, blue: 0.8))
                }
                if selectedDigits >= 3 {
                    previewCard(drawing: hundredsDrawing, position: .hundreds, label: "ひゃく", color: Color(red: 0.25, green: 0.55, blue: 0.85))
                }
                if selectedDigits >= 2 {
                    previewCard(drawing: tensDrawing, position: .tens, label: "じゅう", color: Color(red: 0.35, green: 0.65, blue: 0.35))
                }
                previewCard(drawing: onesDrawing, position: .ones, label: "いち", color: Color(red: 0.9, green: 0.4, blue: 0.35))
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // 中央：メインキャンバス (手動遷移付き)
            HStack(spacing: 12) {
                Button(action: {
                    retreatToPreviousPosition()
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(canRetreat() ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.gray.opacity(0.2))
                }
                .disabled(!canRetreat())
                
                mainCanvasCard(color: activeColor(), canvasSize: 200)
                
                Button(action: {
                    advanceToNextPosition()
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(canAdvance() ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.gray.opacity(0.2))
                }
                .disabled(!canAdvance())
            }
            
            // 正解・不正解時の表示
            if answerStatus == .incorrect {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("せいかい：")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                        
                        HStack(spacing: 6) {
                            if selectedDigits >= 4 {
                                Text(String(currentNumber / 1000))
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                            }
                            if selectedDigits >= 3 {
                                Text(String((currentNumber % 1000) / 100))
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.25, green: 0.55, blue: 0.85))
                            }
                            if selectedDigits >= 2 {
                                Text(String((currentNumber % 100) / 10))
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.35))
                            }
                            Text(String(currentNumber % 10))
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.cardBackground(for: colorScheme))
                        .cornerRadius(10)
                    }
                    
                    Text(JapaneseNumberFormatter.toFuriganaSpaced(currentNumber))
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.3))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(colorScheme == .dark ? Color(red: 0.35, green: 0.18, blue: 0.15) : Color(red: 1.0, green: 0.92, blue: 0.92))
                        .cornerRadius(12)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer(minLength: 4)
            
            controlButtonsView(cardWidth: 200, cardHeight: 200)
                .frame(height: 60)
            
            Spacer(minLength: 4)
        }
    }
    
    // 横向きレイアウト
    @ViewBuilder
    private func landscapeLayout(size: CGSize) -> some View {
        let leftWidth = size.width * 0.58
        let rightWidth = size.width * 0.36
        
        return HStack(spacing: 24) {
            // 左側半分: 手書きエリア（プレビュー＋メインキャンバス）
            VStack(spacing: 8) {
                Spacer()
                
                // ミニプレビュー
                HStack(spacing: 10) {
                    if selectedDigits >= 4 {
                        previewCard(drawing: thousandsDrawing, position: .thousands, label: "せん", color: Color(red: 0.6, green: 0.4, blue: 0.8))
                    }
                    if selectedDigits >= 3 {
                        previewCard(drawing: hundredsDrawing, position: .hundreds, label: "ひゃく", color: Color(red: 0.25, green: 0.55, blue: 0.85))
                    }
                    if selectedDigits >= 2 {
                        previewCard(drawing: tensDrawing, position: .tens, label: "じゅう", color: Color(red: 0.35, green: 0.65, blue: 0.35))
                    }
                    previewCard(drawing: onesDrawing, position: .ones, label: "いち", color: Color(red: 0.9, green: 0.4, blue: 0.35))
                }
                
                // メインキャンバス（手動遷移矢印付き）
                HStack(spacing: 12) {
                    Button(action: {
                        retreatToPreviousPosition()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(canRetreat() ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.gray.opacity(0.2))
                    }
                    .disabled(!canRetreat())
                    
                    mainCanvasCard(color: activeColor(), canvasSize: 155)
                    
                    Button(action: {
                        advanceToNextPosition()
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(canAdvance() ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.gray.opacity(0.2))
                    }
                    .disabled(!canAdvance())
                }
                
                if answerStatus == .incorrect {
                    HStack(spacing: 8) {
                        Text("せいかい：")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                        
                        HStack(spacing: 6) {
                            if selectedDigits >= 4 {
                                Text(String(currentNumber / 1000))
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                            }
                            if selectedDigits >= 3 {
                                Text(String((currentNumber % 1000) / 100))
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.25, green: 0.55, blue: 0.85))
                            }
                            if selectedDigits >= 2 {
                                Text(String((currentNumber % 100) / 10))
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.35))
                            }
                            Text(String(currentNumber % 10))
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.cardBackground(for: colorScheme))
                        .cornerRadius(8)
                        
                        Text(JapaneseNumberFormatter.toFuriganaSpaced(currentNumber))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.3))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(colorScheme == .dark ? Color(red: 0.35, green: 0.18, blue: 0.15) : Color(red: 1.0, green: 0.92, blue: 0.92))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .frame(width: leftWidth)
            
            Divider()
                .background(Color.appText(for: colorScheme).opacity(0.15))
                .padding(.vertical, 8)
            
            // 右側半分: ヘッダー、設定、おとをきく、コントロール
            VStack(spacing: 12) {
                HStack {
                    Text("すうじアドベンチャー")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.body)
                            .scaleEffect(animateStar ? 1.5 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animateStar)
                        Text("\(starsCount)")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground(for: colorScheme).opacity(0.8))
                    .cornerRadius(15)
                }
                
                // 桁数選択（右側に移動）
                HStack(spacing: 8) {
                    ForEach([1, 2, 3, 4], id: \.self) { digit in
                        Button(action: {
                            selectedDigits = digit
                        }) {
                            Text("\(digit)けた")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(selectedDigits == digit ? .white : Color.appText(for: colorScheme).opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedDigits == digit ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.cardBackground(for: colorScheme))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.top, 4)
                
                Spacer()
                
                // おとをきくボタン（右側に移動）
                Button(action: {
                    playQuestionVoice()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.2))
                        Text("おとをきく")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3)
                }
                
                Spacer()
                
                controlButtonsView(cardWidth: 155, cardHeight: 155)
                    .frame(height: 80)
                
                Spacer()
            }
            .frame(width: rightWidth)
        }
        .padding(.horizontal)
    }
    
    // コントロールボタン
    @ViewBuilder
    private func controlButtonsView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        if answerStatus == .none {
            HStack(spacing: 16) {
                Button(action: {
                    clearActiveDrawing()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("けす")
                    }
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.3))
                    .frame(width: 110, height: 48)
                    .background(colorScheme == .dark ? Color(red: 0.25, green: 0.18, blue: 0.15) : Color(red: 0.95, green: 0.9, blue: 0.85))
                    .cornerRadius(24)
                }
                
                Button(action: {
                    checkWritingAnswer(cardWidth: cardWidth, cardHeight: cardHeight)
                }) {
                    ZStack {
                        if isRecognizing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("できた！")
                            }
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 130, height: 48)
                    .background(isRecognizing || isDrawingEmpty() ? Color.gray : Color(red: 0.35, green: 0.7, blue: 0.35))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                }
                .disabled(isRecognizing || isDrawingEmpty())
            }
        } else {
            HStack(spacing: 24) {
                if answerStatus == .incorrect {
                    Button(action: {
                        resetAnswer()
                    }) {
                        Text("もういちど")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.appText(for: colorScheme))
                            .frame(width: 120, height: 48)
                            .background(Color.cardBackground(for: colorScheme))
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.appText(for: colorScheme).opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                
                Button(action: {
                    generateNewNumber()
                }) {
                    Text("つぎへ")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 140, height: 48)
                        .background(Color(red: 0.35, green: 0.7, blue: 0.35))
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                }
            }
        }
    }
    
    private func previewCard(drawing: PKDrawing, position: DigitPosition, label: String, color: Color) -> some View {
        let isActive = activePosition == position
        return VStack(spacing: 4) {
            ZStack {
                Color.cardBackground(for: colorScheme)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: isActive ? 6 : 2, x: 0, y: isActive ? 4 : 1)
                
                PKDrawingPreview(drawing: drawing, colorScheme: colorScheme)
                    .frame(width: 55, height: 75)
                    .padding(8)
            }
            .frame(width: 70, height: 95)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color(red: 0.95, green: 0.55, blue: 0.2) : color.opacity(0.3), lineWidth: isActive ? 3 : 1.5)
            )
            .scaleEffect(isActive ? 1.08 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                autoAdvanceTask?.cancel()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    activePosition = position
                }
            }
            
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(isActive ? Color(red: 0.95, green: 0.55, blue: 0.2) : color.opacity(0.8))
        }
    }
    
    private func mainCanvasCard(color: Color, canvasSize: CGFloat) -> some View {
        let halfSize = canvasSize / 2
        return VStack(spacing: 6) {
            ZStack {
                Color.cardBackground(for: colorScheme)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 6, x: 0, y: 3)
                
                // 十字ガイドライン
                Path { path in
                    path.move(to: CGPoint(x: 10, y: halfSize))
                    path.addLine(to: CGPoint(x: canvasSize - 10, y: halfSize))
                    path.move(to: CGPoint(x: halfSize, y: 10))
                    path.addLine(to: CGPoint(x: halfSize, y: canvasSize - 10))
                }
                .stroke(color.opacity(colorScheme == .dark ? 0.25 : 0.15), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                
                CanvasView(drawing: activeDrawingBinding, clearTrigger: clearTrigger)
                    .frame(width: canvasSize, height: canvasSize)
                    .cornerRadius(20)
            }
            .frame(width: canvasSize, height: canvasSize)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.3), lineWidth: 3)
            )
            
            Text(activeLabel())
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(color.opacity(0.8))
        }
    }
    
    private func resultOverlayView() -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if answerStatus == .correct {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.35))
                        
                        Text("はなまる！")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.35))
                        
                        Text("せいかい！すばらしい！")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(30)
                    .shadow(radius: 10)
                } else if answerStatus == .incorrect {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        
                        Text("おしい！")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                        
                        Text("もういちど チャレンジしてみよう")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .background(Color.cardBackground(for: colorScheme))
                    .cornerRadius(30)
                    .shadow(radius: 10)
                }
            }
        }
    }
    
    private func applyRetryRequest(_ request: RetryRequest) {
        guard !self.isApplyingRetry else { return }
        self.isApplyingRetry = true
        
        self.selectedDigits = request.digits
        self.currentNumber = request.number
        self.answerStatus = .none
        self.showResultOverlay = false
        
        self.clearAllDrawings()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            playQuestionVoice()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isApplyingRetry = false
            if historyManager.retryRequest == request {
                historyManager.retryRequest = nil
            }
        }
    }
    
    private func generateNewNumber() {
        speechSynthesizer.stop()
        answerStatus = .none
        showResultOverlay = false
        
        clearAllDrawings()
        
        switch selectedDigits {
        case 1:
            currentNumber = Int.random(in: 1...9)
            activePosition = .ones
        case 2:
            currentNumber = Int.random(in: 10...99)
            activePosition = .tens
        case 3:
            currentNumber = Int.random(in: 100...999)
            activePosition = .hundreds
        default:
            currentNumber = Int.random(in: 1000...9999)
            activePosition = .thousands
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            playQuestionVoice()
        }
    }
    
    private func resetAnswer() {
        speechSynthesizer.stop()
        answerStatus = .none
        showResultOverlay = false
        
        clearAllDrawings()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playQuestionVoice()
        }
    }
    
    private func playQuestionVoice() {
        let expectedReading = JapaneseNumberFormatter.toJapaneseReading(currentNumber)
        speechSynthesizer.speak(expectedReading)
    }
    
    private func playCorrectVoice() {
        let expectedReading = JapaneseNumberFormatter.toJapaneseReading(currentNumber)
        speechSynthesizer.speak("せいかいは、\(expectedReading)、です")
    }
    
    private func clearAllDrawings() {
        thousandsDrawing = PKDrawing()
        hundredsDrawing = PKDrawing()
        tensDrawing = PKDrawing()
        onesDrawing = PKDrawing()
        clearTrigger.toggle()
        
        // 最初の桁にフォーカスを戻す
        withAnimation {
            switch selectedDigits {
            case 1: activePosition = .ones
            case 2: activePosition = .tens
            case 3: activePosition = .hundreds
            default: activePosition = .thousands
            }
        }
    }
    
    private func clearActiveDrawing() {
        switch activePosition {
        case .thousands: thousandsDrawing = PKDrawing()
        case .hundreds: hundredsDrawing = PKDrawing()
        case .tens: tensDrawing = PKDrawing()
        case .ones: onesDrawing = PKDrawing()
        }
        clearTrigger.toggle()
    }
    
    private func isDrawingEmpty() -> Bool {
        let isThousandsEmpty = selectedDigits >= 4 ? thousandsDrawing.bounds.isEmpty : false
        let isHundredsEmpty = selectedDigits >= 3 ? hundredsDrawing.bounds.isEmpty : false
        let isTensEmpty = selectedDigits >= 2 ? tensDrawing.bounds.isEmpty : false
        let isOnesEmpty = onesDrawing.bounds.isEmpty
        
        if selectedDigits == 4 {
            return isThousandsEmpty || isHundredsEmpty || isTensEmpty || isOnesEmpty
        } else if selectedDigits == 3 {
            return isHundredsEmpty || isTensEmpty || isOnesEmpty
        } else if selectedDigits == 2 {
            return isTensEmpty || isOnesEmpty
        } else {
            return isOnesEmpty
        }
    }
    
    private func checkWritingAnswer(cardWidth: CGFloat, cardHeight: CGFloat) {
        isRecognizing = true
        
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            let expectedThousands = selectedDigits >= 4 ? String(currentNumber / 1000) : ""
            let expectedHundreds = selectedDigits >= 3 ? String((currentNumber % 1000) / 100) : ""
            let expectedTens = selectedDigits >= 2 ? String((currentNumber % 100) / 10) : ""
            let expectedOnes = String(currentNumber % 10)
            
            var recognizedThousands = ""
            var recognizedHundreds = ""
            var recognizedTens = ""
            var recognizedOnes = ""
            let canvasRect = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
            
            if selectedDigits >= 4 {
                recognizedThousands = await HandwritingRecognizer.recognizeDigit(from: thousandsDrawing, in: canvasRect, expected: expectedThousands)
            }
            if selectedDigits >= 3 {
                recognizedHundreds = await HandwritingRecognizer.recognizeDigit(from: hundredsDrawing, in: canvasRect, expected: expectedHundreds)
            }
            if selectedDigits >= 2 {
                recognizedTens = await HandwritingRecognizer.recognizeDigit(from: tensDrawing, in: canvasRect, expected: expectedTens)
            }
            recognizedOnes = await HandwritingRecognizer.recognizeDigit(from: onesDrawing, in: canvasRect, expected: expectedOnes)
            
            await MainActor.run {
                isRecognizing = false
                
                let thousandsCorrect = selectedDigits >= 4 ? (recognizedThousands == expectedThousands) : true
                let hundredsCorrect = selectedDigits >= 3 ? (recognizedHundreds == expectedHundreds) : true
                let tensCorrect = selectedDigits >= 2 ? (recognizedTens == expectedTens) : true
                let onesCorrect = recognizedOnes == expectedOnes
                
                let isCorrect = thousandsCorrect && hundredsCorrect && tensCorrect && onesCorrect
                
                // ユーザーの入力値を組み立てる
                var userResponse = ""
                if selectedDigits >= 4 { userResponse += recognizedThousands.isEmpty ? "_" : recognizedThousands }
                if selectedDigits >= 3 { userResponse += recognizedHundreds.isEmpty ? "_" : recognizedHundreds }
                if selectedDigits >= 2 { userResponse += recognizedTens.isEmpty ? "_" : recognizedTens }
                userResponse += recognizedOnes.isEmpty ? "_" : recognizedOnes
                
                // 履歴を保存（正解時はここで starsCount が加算される）
                historyManager.addRecord(
                    mode: .write,
                    digits: selectedDigits,
                    questionNumber: currentNumber,
                    isCorrect: isCorrect,
                    userResponse: userResponse
                )
                
                if isCorrect {
                    answerStatus = .correct
                    animateStar = true
                    
                    HapticManager.shared.playCorrectHaptic()
                    SoundManager.shared.playCorrect()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        animateStar = false
                    }
                } else {
                    answerStatus = .incorrect
                    HapticManager.shared.playIncorrectHaptic()
                    SoundManager.shared.playIncorrect()
                    playCorrectVoice()
                }
                
                showResultOverlay = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation {
                        showResultOverlay = false
                    }
                    
                    if isCorrect {
                        generateNewNumber()
                    }
                }
            }
        }
    }
    
    private func triggerAutoAdvanceTimer(for drawing: PKDrawing) {
        guard activePosition != .ones else { return }
        guard !drawing.bounds.isEmpty else { return }
        
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    advanceToNextPosition()
                }
            }
        }
    }
    
    private func advanceToNextPosition() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch activePosition {
        case .thousands:
            activePosition = .hundreds
        case .hundreds:
            activePosition = .tens
        case .tens:
            activePosition = .ones
        case .ones:
            break
        }
    }
    
    private func retreatToPreviousPosition() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch activePosition {
        case .thousands:
            break
        case .hundreds:
            if selectedDigits >= 4 { activePosition = .thousands }
        case .tens:
            if selectedDigits >= 3 { activePosition = .hundreds }
        case .ones:
            if selectedDigits >= 2 { activePosition = .tens }
        }
    }
    
    private func canRetreat() -> Bool {
        switch activePosition {
        case .thousands:
            return false
        case .hundreds:
            return selectedDigits >= 4
        case .tens:
            return selectedDigits >= 3
        case .ones:
            return selectedDigits >= 2
        }
    }
    
    private func canAdvance() -> Bool {
        return activePosition != .ones
    }
    
    private func activeColor() -> Color {
        switch activePosition {
        case .thousands: return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .hundreds: return Color(red: 0.25, green: 0.55, blue: 0.85)
        case .tens: return Color(red: 0.35, green: 0.65, blue: 0.35)
        case .ones: return Color(red: 0.9, green: 0.4, blue: 0.35)
        }
    }
    
    private func activeLabel() -> String {
        switch activePosition {
        case .thousands: return "せんのへや"
        case .hundreds: return "ひゃくのへや"
        case .tens: return "じゅうのへや"
        case .ones: return "いちのへや"
        }
    }
}

// MARK: - 設定画面 (Settings View)
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showingSupportSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                Form {
                    Section(header: Text("アプリについて").font(.system(.subheadline, design: .rounded)).fontWeight(.bold)) {
                        HStack {
                            Text("アプリ名")
                            Spacer()
                            Text("すうじアドベンチャー")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(.body, design: .rounded))
                        
                        HStack {
                            Text("バージョン")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(.body, design: .rounded))
                    }
                    
                    Section(header: Text("アプリのサポート").font(.system(.subheadline, design: .rounded)).fontWeight(.bold)) {
                        Button(action: {
                            showingSupportSheet = true
                        }) {
                            HStack {
                                Text("☕️ 開発者を応援する (Tip Jar)")
                                    .foregroundColor(Color.appText(for: colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.system(.body, design: .rounded))
                    }
                }
                .background(Color.clear)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("せってい")
            .sheet(isPresented: $showingSupportSheet) {
                SupportSheetView()
            }
        }
    }
}

// MARK: - サポート用シートコンテナ
struct SupportSheetView: View {
    @State private var isUnlocked = false
    
    var body: some View {
        if isUnlocked {
            TipJarView()
        } else {
            ParentalGateView(isUnlocked: $isUnlocked)
        }
    }
}

// MARK: - ペアレンタルゲート (Parental Gate View)
struct ParentalGateView: View {
    @Binding var isUnlocked: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var num1 = Int.random(in: 5...15)
    @State private var num2 = Int.random(in: 5...15)
    @State private var answerInput = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showErrorMessage = false
    
    var correctAnswer: Int {
        num1 + num2
    }
    
    var body: some View {
        ZStack {
            Color.appBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // ヘッダー閉じるボタン
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding(.trailing, 20)
                            .padding(.top, 15)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("🔒 ほごしゃのかたへ")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Text("これはおとな用のページです。\nつぎのけいさんを といてください。")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 計算問題
                HStack(spacing: 10) {
                    Text("\(num1)")
                    Text("+")
                    Text("\(num2)")
                    Text("=")
                    
                    // 入力欄
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground(for: colorScheme))
                            .frame(width: 80, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showErrorMessage ? Color.red : Color.orange.opacity(0.5), lineWidth: 2)
                            )
                        
                        Text(answerInput.isEmpty ? "?" : answerInput)
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(answerInput.isEmpty ? .secondary : Color.appText(for: colorScheme))
                    }
                }
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.black)
                .foregroundColor(Color.appText(for: colorScheme))
                .offset(x: shakeOffset)
                
                if showErrorMessage {
                    Text("こたえが ちがいます。もういちど といてね！")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.red)
                        .transition(.opacity)
                } else {
                    Text(" ") // レイアウトがズレないためのプレースホルダー
                        .font(.system(.footnote, design: .rounded))
                }
                
                Spacer()
                
                // カスタムキーパッド
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(1..<4, id: \.self) { col in
                                let number = row * 3 + col
                                keypadButton(label: "\(number)") {
                                    appendNumber("\(number)")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        // クリア / 一字消去ボタン
                        keypadButton(label: "⌫") {
                            deleteLast()
                        }
                        
                        keypadButton(label: "0") {
                            appendNumber("0")
                        }
                        
                        // 決定ボタン
                        Button(action: {
                            submitAnswer()
                        }) {
                            Text("決定")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 60)
                                .background(Color.orange)
                                .cornerRadius(30)
                                .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    private func keypadButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Color.appText(for: colorScheme))
                .frame(width: 80, height: 60)
                .background(Color.cardBackground(for: colorScheme))
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
    
    private func appendNumber(_ number: String) {
        if answerInput.count < 3 {
            withAnimation(.easeOut(duration: 0.15)) {
                showErrorMessage = false
                answerInput += number
            }
        }
    }
    
    private func deleteLast() {
        if !answerInput.isEmpty {
            withAnimation(.easeOut(duration: 0.15)) {
                showErrorMessage = false
                answerInput.removeLast()
            }
        }
    }
    
    private func submitAnswer() {
        if let inputVal = Int(answerInput), inputVal == correctAnswer {
            // 正解
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
            withAnimation {
                isUnlocked = true
            }
        } else {
            // 不正解時の演出
            SoundManager.shared.playIncorrect()
            HapticManager.shared.playIncorrectHaptic()
            
            withAnimation(.default) {
                showErrorMessage = true
            }
            
            // 左右に揺らすアニメーション
            let animationDuration = 0.08
            for i in 0..<4 {
                let offset: CGFloat = i % 2 == 0 ? 10 : -10
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * animationDuration) {
                    withAnimation(.linear(duration: animationDuration)) {
                        self.shakeOffset = offset
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0 * animationDuration) {
                withAnimation(.linear(duration: animationDuration)) {
                    self.shakeOffset = 0
                    self.answerInput = ""
                    // 新しい問題を生成
                    self.num1 = Int.random(in: 5...15)
                    self.num2 = Int.random(in: 5...15)
                }
            }
        }
    }
}

// MARK: - 開発者応援 (Tip Jar View)
struct TipJarView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var storeManager = StoreManager.shared
    
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var successScale: CGFloat = 0.5
    @State private var starsAnimating = false
    
    var body: some View {
        ZStack {
            Color.appBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if showSuccess {
                // 応援感謝完了画面
                VStack(spacing: 25) {
                    Spacer()
                    
                    // アニメーション付きスター
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                            .scaleEffect(successScale)
                        
                        // 周りの飛び散る小さな星々
                        ForEach(0..<8, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                                .offset(y: starsAnimating ? -90 : 0)
                                .rotationEffect(.degrees(Double(index) * 45))
                                .opacity(starsAnimating ? 0 : 1)
                                .scaleEffect(starsAnimating ? 0.3 : 1.0)
                        }
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                            successScale = 1.0
                        }
                        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                            starsAnimating = true
                        }
                    }
                    
                    Text("ありがとうございました！")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Text("あたたかいごうえんを いただき、とってもうれしいです！いただいたサポートは、今後のアップデート（子どもたちの学習を豊かにする新機能の追加など）のために大切に使わせていただきます。")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .lineSpacing(6)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("とじる")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.orange)
                            .cornerRadius(28)
                            .shadow(color: Color.orange.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            } else {
                // プラン選択画面
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 20)
                                .padding(.top, 15)
                        }
                    }
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // タイトル・説明
                            VStack(spacing: 12) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                                    .padding(.top, 10)
                                
                                Text("開発者を応援する")
                                    .font(.system(.title, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.appText(for: colorScheme))
                                
                                Text("「すうじアドベンチャー」は個人で開発しています。もし気に入っていただけましたら、今後のアップデート（より子どもたちの学習を補う追加機能など）を継続するためのサポートをいただけますと大変励みになります。")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .lineSpacing(4)
                            }
                            
                            // プランの選択肢
                            if storeManager.products.isEmpty {
                                VStack(spacing: 15) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                        .scaleEffect(1.2)
                                    Text("商品を読み込み中...")
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 40)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(storeManager.products) { product in
                                        let emoji: String = {
                                            if product.id.contains("_160") { return "☕️" }
                                            if product.id.contains("_480") { return "🍰" }
                                            return "🚀"
                                        }()
                                        
                                        supportPlanCard(
                                            emoji: emoji,
                                            title: product.displayName,
                                            description: product.description,
                                            price: product.displayPrice
                                        ) {
                                            Task {
                                                await buy(product)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
                .disabled(isProcessing)
                .overlay(
                    Group {
                        if isProcessing {
                            ZStack {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()
                                
                                VStack(spacing: 15) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    
                                    Text("通信中...")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 120, height: 120)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(16)
                            }
                        }
                    }
                )
            }
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
    }
    
    private func supportPlanCard(
        emoji: String,
        title: String,
        description: String,
        price: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Text(description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(20)
                    .shadow(color: Color.orange.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .padding()
            .background(Color.cardBackground(for: colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private func buy(_ product: Product) async {
        isProcessing = true
        let success = await storeManager.purchase(product)
        isProcessing = false
        
        if success {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                showSuccess = true
            }
            SoundManager.shared.playCorrect()
            HapticManager.shared.playCorrectHaptic()
        }
    }
}


#Preview {
    ContentView()
}

// MARK: - PKDrawing Preview View
struct PKDrawingPreview: View {
    let drawing: PKDrawing
    let colorScheme: ColorScheme
    
    var body: some View {
        GeometryReader { geometry in
            if drawing.strokes.isEmpty {
                Color.clear
            } else {
                let strokeColor: UIColor = colorScheme == .dark
                    ? UIColor(red: 0.92, green: 0.89, blue: 0.84, alpha: 1.0)
                    : UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
                
                let themed = themedDrawing(from: drawing, with: strokeColor)
                if let image = generatePreviewImage(from: themed, targetSize: geometry.size) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
    
    private func themedDrawing(from original: PKDrawing, with color: UIColor) -> PKDrawing {
        var themed = PKDrawing()
        for stroke in original.strokes {
            var newStroke = stroke
            newStroke.ink = PKInk(.pen, color: color)
            themed.strokes.append(newStroke)
        }
        return themed
    }
    
    private func generatePreviewImage(from drawing: PKDrawing, targetSize: CGSize) -> UIImage? {
        let drawingBounds = drawing.bounds
        guard !drawingBounds.isEmpty else { return nil }
        
        let maxSide = max(drawingBounds.width, drawingBounds.height)
        let paddedSide = max(maxSide * 1.35, 40.0)
        let centerX = drawingBounds.midX
        let centerY = drawingBounds.midY
        
        let cropRect = CGRect(
            x: centerX - paddedSide / 2,
            y: centerY - paddedSide / 2,
            width: paddedSide,
            height: paddedSide
        )
        
        return drawing.image(from: cropRect, scale: 2.0)
    }
}

// MARK: - StoreKit 2 課金マネージャー
@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    
    private let productIDs = [
        "jp.junya.NumberAdventure.support_160",
        "jp.junya.NumberAdventure.support_480",
        "jp.junya.NumberAdventure.support_1000"
    ]
    
    static let shared = StoreManager()
    private var transactionListener: Task<Void, Error>?
    
    init() {
        transactionListener = Task {
            for await result in StoreKit.Transaction.updates {
                await handle(transactionResult: result)
            }
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    func loadProducts() async {
        do {
            let loadedProducts = try await Product.products(for: productIDs)
            self.products = loadedProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to load products from App Store: \(error)")
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                case .unverified:
                    print("Transaction failed verification.")
                    return false
                }
            case .pending:
                print("Transaction pending.")
                return false
            case .userCancelled:
                print("User cancelled purchase.")
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase failed with error: \(error)")
            return false
        }
    }
    
    private func handle(transactionResult: VerificationResult<StoreKit.Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified:
            break
        }
    }
}
