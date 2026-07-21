import Foundation
import Combine

enum ActivityMode: String, Codable {
    case read = "よむ"
    case write = "かく"
    case dotToDot = "てんつなぎ"
    case combine = "あわせる"
    case arShooting = "ARシューティング"
}

struct RetryRequest: Equatable {
    let mode: ActivityMode
    let digits: Int
    let number: Int
}

struct HistoryRecord: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let dateString: String // "yyyy-MM-dd" 形式
    let mode: ActivityMode
    let digits: Int
    let questionNumber: Int // 出題された数字
    let isCorrect: Bool
    let userResponse: String // 音声または手書き認識テキスト
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var records: [HistoryRecord] = []
    @Published var starsCount: Int = 0 {
        didSet {
            UserDefaults.standard.set(starsCount, forKey: "starsCount")
        }
    }
    
    @Published var unlockedStage: Int = 1 {
        didSet {
            UserDefaults.standard.set(unlockedStage, forKey: "unlockedStage")
        }
    }
    
    @Published var unlockedAnimalIds: [String] = [] {
        didSet {
            UserDefaults.standard.set(unlockedAnimalIds, forKey: "unlockedAnimalIds")
        }
    }
    
    // 再挑戦リクエスト
    @Published var retryRequest: RetryRequest? = nil
    
    private let fileURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("history_records.json")
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {
        self.starsCount = UserDefaults.standard.integer(forKey: "starsCount")
        
        // unlockedStageの初期値は1にする（保存されていなければ1）
        let savedStage = UserDefaults.standard.integer(forKey: "unlockedStage")
        self.unlockedStage = savedStage > 0 ? savedStage : 1
        
        self.unlockedAnimalIds = UserDefaults.standard.stringArray(forKey: "unlockedAnimalIds") ?? []
        loadRecords()
    }
    
    func addRecord(mode: ActivityMode, digits: Int, questionNumber: Int, isCorrect: Bool, userResponse: String) {
        let now = Date()
        let record = HistoryRecord(
            date: now,
            dateString: dateFormatter.string(from: now),
            mode: mode,
            digits: digits,
            questionNumber: questionNumber,
            isCorrect: isCorrect,
            userResponse: userResponse
        )
        records.append(record)
        saveRecords()
        
        // 正解の場合は星を増やす
        if isCorrect {
            starsCount += 1
        }
    }
    
    func loadRecords() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            records = try decoder.decode([HistoryRecord].self, from: data)
        } catch {
            print("Failed to load records or file does not exist: \(error)")
            records = []
        }
    }
    
    func saveRecords() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save records: \(error)")
        }
    }
    
    func resetAll() {
        records = []
        starsCount = 0
        unlockedStage = 1
        unlockedAnimalIds = []
        saveRecords()
    }
    
    func unlockNextStage() {
        unlockedStage += 1
    }
    
    func unlockAnimal(id: String) {
        if !unlockedAnimalIds.contains(id) {
            unlockedAnimalIds.append(id)
        }
    }
    
    func resetHistoryOnly() {
        records = []
        saveRecords()
    }
    
    // 特定の日のレコードを取得
    func records(for date: Date) -> [HistoryRecord] {
        let dateStr = dateFormatter.string(from: date)
        return records.filter { $0.dateString == dateStr }
    }
    
    // 特定の日に履歴があるか
    func hasRecords(for date: Date) -> Bool {
        let dateStr = dateFormatter.string(from: date)
        return records.contains { $0.dateString == dateStr }
    }
    
    // 特定の日の星（正解）の数
    func starCount(for date: Date) -> Int {
        let dateStr = dateFormatter.string(from: date)
        return records.filter { $0.dateString == dateStr && $0.isCorrect }.count
    }
}
