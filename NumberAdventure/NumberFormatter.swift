import Foundation

struct JapaneseNumberFormatter {
    /// 数値を日本語の読みに変換（例：352 -> "さんびゃくごじゅうに"）
    static func toJapaneseReading(_ number: Int) -> String {
        guard number > 0 && number < 10000 else { return "" }
        
        let thousands = number / 1000
        let hundreds = (number % 1000) / 100
        let tens = (number % 100) / 10
        let ones = number % 10
        
        var reading = ""
        
        // 千の位
        switch thousands {
        case 1: reading += "せん"
        case 2: reading += "にせん"
        case 3: reading += "さんぜん"
        case 4: reading += "よんせん"
        case 5: reading += "ごせん"
        case 6: reading += "ろくせん"
        case 7: reading += "ななせん"
        case 8: reading += "はっせん"
        case 9: reading += "きゅうせん"
        default: break
        }
        
        // 百の位
        switch hundreds {
        case 1: reading += "ひゃく"
        case 2: reading += "にひゃく"
        case 3: reading += "さんびゃく"
        case 4: reading += "よんひゃく"
        case 5: reading += "ごひゃく"
        case 6: reading += "ろっぴゃく"
        case 7: reading += "ななひゃく"
        case 8: reading += "はっぴゃく"
        case 9: reading += "きゅうひゃく"
        default: break
        }
        
        // 十の位
        switch tens {
        case 1: reading += "じゅう"
        case 2: reading += "にじゅう"
        case 3: reading += "さんじゅう"
        case 4: reading += "よんじゅう"
        case 5: reading += "ごじゅう"
        case 6: reading += "ろくじゅう"
        case 7: reading += "ななじゅう"
        case 8: reading += "はちじゅう"
        case 9: reading += "きゅうじゅう"
        default: break
        }
        
        // 一の位
        switch ones {
        case 1: reading += "いち"
        case 2: reading += "に"
        case 3: reading += "さん"
        case 4: reading += "よん"
        case 5: reading += "ご"
        case 6: reading += "ろく"
        case 7: reading += "なな"
        case 8: reading += "はち"
        case 9: reading += "きゅう"
        default: break
        }
        
        return reading
    }
    
    /// ふりがな表示用のスペース区切りテキスト（例：352 -> "さんびゃく ごじゅう に"）
    static func toFuriganaSpaced(_ number: Int) -> String {
        guard number > 0 && number < 10000 else { return "" }
        
        let thousands = number / 1000
        let hundreds = (number % 1000) / 100
        let tens = (number % 100) / 10
        let ones = number % 10
        
        var parts: [String] = []
        
        // 千の位
        switch thousands {
        case 1: parts.append("せん")
        case 2: parts.append("にせん")
        case 3: parts.append("さんぜん")
        case 4: parts.append("よんせん")
        case 5: parts.append("ごせん")
        case 6: parts.append("ろくせん")
        case 7: parts.append("ななせん")
        case 8: parts.append("はっせん")
        case 9: parts.append("きゅうせん")
        default: break
        }
        
        // 百の位
        switch hundreds {
        case 1: parts.append("ひゃく")
        case 2: parts.append("にひゃく")
        case 3: parts.append("さんびゃく")
        case 4: parts.append("よんひゃく")
        case 5: parts.append("ごひゃく")
        case 6: parts.append("ろっぴゃく")
        case 7: parts.append("ななひゃく")
        case 8: parts.append("はっぴゃく")
        case 9: parts.append("きゅうひゃく")
        default: break
        }
        
        // 十の位
        switch tens {
        case 1: parts.append("じゅう")
        case 2: parts.append("にじゅう")
        case 3: parts.append("さんじゅう")
        case 4: parts.append("よんじゅう")
        case 5: parts.append("ごじゅう")
        case 6: parts.append("ろくじゅう")
        case 7: parts.append("ななじゅう")
        case 8: parts.append("はちじゅう")
        case 9: parts.append("きゅうじゅう")
        default: break
        }
        
        // 一の位
        switch ones {
        case 1: parts.append("いち")
        case 2: parts.append("に")
        case 3: parts.append("さん")
        case 4: parts.append("よん")
        case 5: parts.append("ご")
        case 6: parts.append("ろく")
        case 7: parts.append("なな")
        case 8: parts.append("はち")
        case 9: parts.append("きゅう")
        default: break
        }
        
        return parts.joined(separator: " ")
    }
}
