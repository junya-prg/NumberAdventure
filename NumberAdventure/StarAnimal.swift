import Foundation
import SwiftUI

struct StarAnimal: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let constellationName: String
    let digit: Int
    let symbol: String // SF Symbols の名前
    let colorHex: String // カードや星座のベースカラー
    let description: String
}

let starAnimals: [StarAnimal] = [
    StarAnimal(id: "animal_1", name: "すうじひつじ", constellationName: "おひつじ座", digit: 1, symbol: "cloud.sun.fill", colorHex: "#FFB7B2", description: "１の形をしたツノを持つ、のんびりやの羊。夜空をフワフワお散歩するのが大好き。"),
    StarAnimal(id: "animal_2", name: "すうじおうし", constellationName: "おうし座", digit: 2, symbol: "tortoise.fill", colorHex: "#FFDAC1", description: "２のカーブにそっくりなツノを持つ力持ちの牛。みんなを乗せて走るよ。"),
    StarAnimal(id: "animal_3", name: "すうじうさぎ", constellationName: "ふたご座", digit: 3, symbol: "pawprint.fill", colorHex: "#E2F0CB", description: "３の耳を持つ双子のウサギ。いつも仲良くぴょんぴょん跳ねているよ。"),
    StarAnimal(id: "animal_4", name: "すうじがに", constellationName: "かに座", digit: 4, symbol: "ladybug.fill", colorHex: "#B5EAD7", description: "４のハサミを持つカニ。暗い夜空でも星をチョキチョキ磨いてピカピカにするよ。"),
    StarAnimal(id: "animal_5", name: "すうじらいおん", constellationName: "しし座", digit: 5, symbol: "cat.fill", colorHex: "#C7CEEA", description: "５のたてがみを持つ勇敢なライオン。ほえると夜空に星が流れるよ。"),
    StarAnimal(id: "animal_6", name: "すうじおとめ", constellationName: "おとめ座", digit: 6, symbol: "sparkles", colorHex: "#E8C4EC", description: "６の羽を持つ天使のような小鳥。優しい歌声で星たちを眠らせるよ。"),
    StarAnimal(id: "animal_7", name: "すうじてんびん", constellationName: "てんびん座", digit: 7, symbol: "scale.3d", colorHex: "#FFEDA6", description: "７の形の天秤に乗ったフクロウ。夜空の星の重さを毎日計っているよ。"),
    StarAnimal(id: "animal_8", name: "すうじさそり", constellationName: "さそり座", digit: 8, symbol: "ant.fill", colorHex: "#FFC6FF", description: "８の尾を持つサソリ。ちょっと恥ずかしがり屋だけど、星をともすのが得意。"),
    StarAnimal(id: "animal_9", name: "すうじうま", constellationName: "いて座", digit: 9, symbol: "figure.run", colorHex: "#CAFFBF", description: "９の弓を持つケンタウロス風のウマ。走るのがとっても早くて、流れ星を追いかけるよ。"),
    StarAnimal(id: "animal_10", name: "すうじやぎ", constellationName: "やぎ座", digit: 10, symbol: "fish.fill", colorHex: "#9BF6FF", description: "10のしっぽを持つやぎの魚。星の海をスイスイ泳いで、貝殻の星座を見つけるよ。")
]

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
