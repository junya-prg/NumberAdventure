import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingResetAllAlert = false
    
    private let calendar = Calendar.current
    private let weekdays = ["にち", "げつ", "か", "すい", "もく", "きん", "ど"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 今月のサマリーカード
                            summaryCard()
                                .padding(.horizontal)
                            
                            // カレンダーカード
                            calendarCard()
                                .padding(.horizontal)
                            
                            // 選択日の詳細履歴
                            historyListSection()
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    
                    // バナー広告
                    BannerAdView()
                }
            }
            .navigationTitle("がんばりのきろく")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                showingResetAllAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(Color.appText(for: colorScheme).opacity(0.8))
            })
            .alert("きろくの全削除", isPresented: $showingResetAllAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("すべて消す", role: .destructive) {
                    HistoryManager.shared.resetAll()
                    HapticManager.shared.playIncorrectHaptic()
                }
            } message: {
                Text("これまでの学習履歴とあつめた星をすべて消去します。本当によろしいですか？")
            }
        }
    }
    
    // 今月のサマリー
    private func summaryCard() -> some View {
        let stats = monthlyStats
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今月のがんばり")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.appText(for: colorScheme).opacity(0.7))
                
                Text(monthYearString)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.black)
                    .foregroundColor(Color.appText(for: colorScheme))
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("⭐️")
                        .font(.title3)
                    Text("\(stats.stars) こ")
                        .font(.system(.body, design: .rounded).bold())
                    Text("あつめた星")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("📝")
                        .font(.title3)
                    Text("\(stats.total) かい")
                        .font(.system(.body, design: .rounded).bold())
                    Text("といた数")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("🎯")
                        .font(.title3)
                    Text(String(format: "%.0f%%", stats.correctRate))
                        .font(.system(.body, design: .rounded).bold())
                    Text("せいかいりつ")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground(for: colorScheme))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, x: 0, y: 2)
    }
    
    // カレンダー表示
    private func calendarCard() -> some View {
        VStack(spacing: 12) {
            // 月の切り替えヘッダー
            HStack {
                Button(action: {
                    changeMonth(by: -1)
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.2))
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.appText(for: colorScheme))
                
                Spacer()
                
                Button(action: {
                    changeMonth(by: 1)
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.2))
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            // 曜日ヘッダー
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(dayColor(for: day))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 日付グリッド
            let days = daysInMonth(for: currentMonth)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<days.count, id: \.self) { index in
                    dayCell(date: days[index])
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground(for: colorScheme))
        .cornerRadius(22)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 6, x: 0, y: 3)
    }
    
    // 日付セル
    private func dayCell(date: Date?) -> some View {
        VStack(spacing: 4) {
            if let date = date {
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)
                let dayNum = calendar.component(.day, from: date)
                
                let hasRecord = historyManager.hasRecords(for: date)
                let stars = historyManager.starCount(for: date)
                
                Text("\(dayNum)")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundColor(isSelected ? .white : (isToday ? Color(red: 0.95, green: 0.55, blue: 0.2) : Color.appText(for: colorScheme)))
                    .frame(width: 34, height: 34)
                    .background(
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.55, blue: 0.2))
                            } else if isToday {
                                Circle()
                                    .stroke(Color(red: 0.95, green: 0.55, blue: 0.2), lineWidth: 2)
                            }
                        }
                    )
                
                // がんばりスタンプ (星)
                HStack(spacing: 1) {
                    if hasRecord {
                        if stars >= 5 {
                            Text("👑")
                                .font(.system(size: 10))
                        } else if stars >= 3 {
                            Text("✨")
                                .font(.system(size: 10))
                        } else if stars >= 1 {
                            Text("⭐️")
                                .font(.system(size: 10))
                        } else {
                            Text("✏️") // 解いたが正解なし
                                .font(.system(size: 9))
                        }
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
                .frame(height: 10)
            } else {
                Spacer()
                    .frame(width: 34, height: 48)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let date = date {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedDate = date
            }
        }
    }
    
    // 詳細履歴セクション
    private func historyListSection() -> some View {
        let records = historyManager.records(for: selectedDate)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                let dateStr = formattedSelectedDate()
                Text("\(dateStr) のきろく")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.appText(for: colorScheme))
                
                Spacer()
                
                Text("\(records.count) かい挑戦")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("この日はまだやっていないよ。\nすうじであそんでみよう！")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.cardBackground(for: colorScheme))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 4)
            } else {
                ForEach(records.reversed()) { record in
                    historyRecordCard(record: record)
                }
            }
        }
    }
    
    // 履歴アイテムカード
    private func historyRecordCard(record: HistoryRecord) -> some View {
        let modeColor: Color
        let modeIcon: String
        let responsePrefix: String
        
        switch record.mode {
        case .read:
            modeColor = Color(red: 0.95, green: 0.55, blue: 0.2)
            modeIcon = "🎤"
            responsePrefix = "こえ:"
        case .write:
            modeColor = Color(red: 0.25, green: 0.55, blue: 0.85)
            modeIcon = "✏️"
            responsePrefix = "かいた:"
        case .dotToDot:
            modeColor = Color.yellow
            modeIcon = "✨"
            responsePrefix = "せいざ:"
        case .combine:
            modeColor = Color.green
            modeIcon = "⚖️"
            responsePrefix = "あわせた:"
        case .arShooting:
            modeColor = Color.orange
            modeIcon = "🎯"
            responsePrefix = "たいむ:"
        }
        
        return HStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Text(modeIcon)
                    .font(.body)
            }
            
            // 問題情報
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.mode.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColor)
                        .cornerRadius(5)
                    
                    Text("\(record.digits)けた")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // 数字と読み仮名
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(record.questionNumber)")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundColor(Color.appText(for: colorScheme))
                    
                    Text(JapaneseNumberFormatter.toJapaneseReading(record.questionNumber))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // ユーザーの回答
                HStack(spacing: 4) {
                    Text(responsePrefix)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text(record.userResponse.isEmpty ? "(なにもなし)" : record.userResponse)
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundColor(record.isCorrect ? .secondary : Color(red: 0.9, green: 0.4, blue: 0.35))
                }
            }
            
            Spacer()
            
            // 判定と再挑戦
            VStack(alignment: .trailing, spacing: 6) {
                if record.isCorrect {
                    HStack(spacing: 3) {
                        Text("せいかい！")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.35))
                        Text("💮")
                            .font(.body)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 3) {
                            Text("おしい！")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.35))
                            Text("⚠️")
                                .font(.caption)
                        }
                        
                        Button(action: {
                            startRetry(record: record)
                        }) {
                            Text("もういちど")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.95, green: 0.55, blue: 0.2))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground(for: colorScheme))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 3, x: 0, y: 1)
    }
    
    // 再挑戦ロジック
    private func startRetry(record: HistoryRecord) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let req = RetryRequest(
            mode: record.mode,
            digits: record.digits,
            number: record.questionNumber
        )
        historyManager.retryRequest = req
        
        withAnimation {
            switch record.mode {
            case .read:
                selectedTab = 0
            case .write:
                selectedTab = 1
            case .dotToDot, .combine, .arShooting:
                selectedTab = 2
            }
        }
    }
    
    // 月変更
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            currentMonth = newMonth
            
            // 選択日付を新しい月の1日に合わせる
            let start = newMonth.startOfMonth()
            selectedDate = start
        }
    }
    
    // 選択日付フォーマッタ
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月 d日"
        return formatter.string(from: selectedDate)
    }
    
    // 曜日ごとの色
    private func dayColor(for weekday: String) -> Color {
        if weekday == "に" {
            return Color(red: 0.9, green: 0.4, blue: 0.35) // 日曜日は赤系
        } else if weekday == "ど" {
            return Color(red: 0.25, green: 0.55, blue: 0.85) // 土曜日は青系
        } else {
            return Color.appText(for: colorScheme).opacity(0.6)
        }
    }
    
    // 今月の統計情報
    private var monthlyStats: (stars: Int, total: Int, correctRate: Double) {
        let records = historyManager.records
        let currentComponents = calendar.dateComponents([.year, .month], from: currentMonth)
        
        let monthlyRecords = records.filter { record in
            let recordComponents = calendar.dateComponents([.year, .month], from: record.date)
            return recordComponents.year == currentComponents.year && recordComponents.month == currentComponents.month
        }
        
        let stars = monthlyRecords.filter { $0.isCorrect }.count
        let total = monthlyRecords.count
        let rate = total > 0 ? (Double(stars) / Double(total)) * 100 : 0.0
        
        return (stars, total, rate)
    }
    
    // 月の日付リスト生成
    private func daysInMonth(for date: Date) -> [Date?] {
        let startOfMonth = date.startOfMonth()
        let endOfMonth = date.endOfMonth()
        
        let numberOfDays = calendar.component(.day, from: endOfMonth)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1: 日曜, 2: 月曜
        
        var days: [Date?] = []
        
        // 前月埋め
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // 今月
        for day in 1...numberOfDays {
            if let dateOfDay = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(dateOfDay)
            }
        }
        
        return days
    }
    
    // 年月ヘッダー文字
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonth)
    }
}

// Dateユーティリティ
private extension Date {
    func startOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: self)))!
    }
    
    func endOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth(using: calendar))!
    }
}
