import SwiftUI
import UIKit

// MARK: - Farben

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func darker(_ f: CGFloat = 0.3) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * (1 - f), green: g * (1 - f), blue: b * (1 - f), alpha: a)
    }

    func mix(_ o: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        o.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

// MARK: - Shop-Katalog

struct CharacterSkin: Identifiable {
    enum Gear { case none, headband, antenna, horns, cape, halo, crown }
    let id: String
    let name: String
    let price: Int
    let body: UIColor
    let accent: UIColor
    let gear: Gear
    let glow: Bool
}

struct JumpEffect: Identifiable {
    enum Style { case dust, sparks, fire, stars, lightning, rainbow }
    let id: String
    let name: String
    let price: Int
    let colors: [UIColor]
    let style: Style
    let symbol: String
}

enum Catalog {
    static let characters: [CharacterSkin] = [
        CharacterSkin(id: "c_jumpy", name: "Jumpy", price: 0, body: UIColor(hex: 0x3D8BFF), accent: UIColor(hex: 0xFFD166), gear: .none, glow: false),
        CharacterSkin(id: "c_ninja", name: "Ninja", price: 150, body: UIColor(hex: 0x2B2D42), accent: UIColor(hex: 0xEF233C), gear: .headband, glow: false),
        CharacterSkin(id: "c_robo", name: "Robo", price: 300, body: UIColor(hex: 0xA9B4C8), accent: UIColor(hex: 0x00F5FF), gear: .antenna, glow: true),
        CharacterSkin(id: "c_devil", name: "Teufel", price: 500, body: UIColor(hex: 0xE63946), accent: UIColor(hex: 0x3D0A12), gear: .horns, glow: false),
        CharacterSkin(id: "c_hero", name: "Superheld", price: 800, body: UIColor(hex: 0x2E86DE), accent: UIColor(hex: 0xEE5253), gear: .cape, glow: false),
        CharacterSkin(id: "c_alien", name: "Alien", price: 1000, body: UIColor(hex: 0x7BED9F), accent: UIColor(hex: 0xFF4FD8), gear: .antenna, glow: true),
        CharacterSkin(id: "c_angel", name: "Engel", price: 1400, body: UIColor(hex: 0xF1F2F6), accent: UIColor(hex: 0xFFD32A), gear: .halo, glow: true),
        CharacterSkin(id: "c_king", name: "König", price: 2500, body: UIColor(hex: 0x7D3C98), accent: UIColor(hex: 0xFFD700), gear: .crown, glow: true),
    ]

    static let effects: [JumpEffect] = [
        JumpEffect(id: "e_dust", name: "Staub", price: 0, colors: [UIColor.white, UIColor(hex: 0xC8D6E5)], style: .dust, symbol: "wind"),
        JumpEffect(id: "e_sparks", name: "Funken", price: 100, colors: [UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFFC300), UIColor(hex: 0xFF7B00)], style: .sparks, symbol: "sparkles"),
        JumpEffect(id: "e_fire", name: "Feuer", price: 250, colors: [UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFFB000), UIColor(hex: 0xFF3D00), UIColor(hex: 0x8B0000)], style: .fire, symbol: "flame.fill"),
        JumpEffect(id: "e_stars", name: "Sternenstaub", price: 400, colors: [UIColor.white, UIColor(hex: 0x9BE7FF), UIColor(hex: 0xC77DFF)], style: .stars, symbol: "star.fill"),
        JumpEffect(id: "e_lightning", name: "Blitz", price: 700, colors: [UIColor.white, UIColor(hex: 0x9EF6FF), UIColor(hex: 0x3A86FF)], style: .lightning, symbol: "bolt.fill"),
        JumpEffect(id: "e_rainbow", name: "Regenbogen", price: 1000, colors: [UIColor(hex: 0xFF595E), UIColor(hex: 0xFFCA3A), UIColor(hex: 0x8AC926), UIColor(hex: 0x1982C4), UIColor(hex: 0x6A4C93)], style: .rainbow, symbol: "rainbow"),
    ]
}

struct RunResult {
    let score: Int
    let collected: Int
    let bonus: Int
    let newRecord: Bool
    let best: Int
}

// MARK: - Speicher (Highscore, Münzen, Käufe)

final class GameStore: ObservableObject {
    static let shared = GameStore()
    private let d = UserDefaults.standard

    @Published var highScore: Int { didSet { d.set(highScore, forKey: "highScore") } }
    @Published var coins: Int { didSet { d.set(coins, forKey: "coins") } }
    @Published var owned: Set<String> { didSet { d.set(Array(owned), forKey: "owned") } }
    @Published var characterID: String { didSet { d.set(characterID, forKey: "character") } }
    @Published var effectID: String { didSet { d.set(effectID, forKey: "effect") } }
    @Published var swapControls: Bool { didSet { d.set(swapControls, forKey: "swap") } }

    private init() {
        highScore = d.integer(forKey: "highScore")
        coins = d.integer(forKey: "coins")
        owned = Set(d.stringArray(forKey: "owned") ?? ["c_jumpy", "e_dust"])
        characterID = d.string(forKey: "character") ?? "c_jumpy"
        effectID = d.string(forKey: "effect") ?? "e_dust"
        swapControls = d.bool(forKey: "swap")
    }

    var character: CharacterSkin { Catalog.characters.first { $0.id == characterID } ?? Catalog.characters[0] }
    var effect: JumpEffect { Catalog.effects.first { $0.id == effectID } ?? Catalog.effects[0] }

    func buy(_ id: String, price: Int) -> Bool {
        guard !owned.contains(id), coins >= price else { return false }
        coins -= price
        owned.insert(id)
        return true
    }

    func finishRun(score: Int, collected: Int) -> RunResult {
        let bonus = score / 25
        let record = score > highScore
        if record { highScore = score }
        coins += collected + bonus
        return RunResult(score: score, collected: collected, bonus: bonus, newRecord: record, best: highScore)
    }
}
