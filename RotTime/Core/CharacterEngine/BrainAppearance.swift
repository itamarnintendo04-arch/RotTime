import SwiftUI

enum BodyColor: String, CaseIterable, Codable, Identifiable {
    case bubblegum, peach, mint, lavender, sky, lemon, midnight, golden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bubblegum: return "Bubblegum"
        case .peach: return "Peach"
        case .mint: return "Mint"
        case .lavender: return "Lavender"
        case .sky: return "Sky"
        case .lemon: return "Lemon"
        case .midnight: return "Midnight"
        case .golden: return "Golden"
        }
    }

    var base: Color {
        switch self {
        case .bubblegum: return Color(hex: 0xFFA3BE)
        case .peach: return Color(hex: 0xFFC29E)
        case .mint: return Color(hex: 0x9FE6C6)
        case .lavender: return Color(hex: 0xC9B6FF)
        case .sky: return Color(hex: 0xA2D5FF)
        case .lemon: return Color(hex: 0xFFE07D)
        case .midnight: return Color(hex: 0x7C74D9)
        case .golden: return Color(hex: 0xFFCF5A)
        }
    }

    var shade: Color {
        switch self {
        case .bubblegum: return Color(hex: 0xF27B9E)
        case .peach: return Color(hex: 0xF39A72)
        case .mint: return Color(hex: 0x62C79F)
        case .lavender: return Color(hex: 0x9F88EE)
        case .sky: return Color(hex: 0x6FB2EC)
        case .lemon: return Color(hex: 0xF1BE45)
        case .midnight: return Color(hex: 0x5448B5)
        case .golden: return Color(hex: 0xE9A42A)
        }
    }

    var outline: Color {
        switch self {
        case .bubblegum: return Color(hex: 0xB44C72)
        case .peach: return Color(hex: 0xB8613F)
        case .mint: return Color(hex: 0x2F8C68)
        case .lavender: return Color(hex: 0x6852B8)
        case .sky: return Color(hex: 0x3878B3)
        case .lemon: return Color(hex: 0xB8821C)
        case .midnight: return Color(hex: 0x2E2580)
        case .golden: return Color(hex: 0xA86A0C)
        }
    }
}

enum HatStyle: String, CaseIterable, Codable, Identifiable {
    case none, beanie, party, crown, wizard, headphones, flowerCrown, gradCap, propeller
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "No hat"
        case .beanie: return "Cozy Beanie"
        case .party: return "Party Cone"
        case .crown: return "Tiny Crown"
        case .wizard: return "Wizard Hat"
        case .headphones: return "Lo-fi Headphones"
        case .flowerCrown: return "Flower Crown"
        case .gradCap: return "Scholar Cap"
        case .propeller: return "Propeller Cap"
        }
    }
    /// Hats that sit over the spark sprout hide it.
    var hidesSprout: Bool { [.beanie, .party, .wizard, .gradCap, .propeller].contains(self) }
}

enum AccessoryStyle: String, CaseIterable, Codable, Identifiable {
    case none, roundGlasses, sunglasses, bowtie, scarf, sweatband, starClip
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Nothing"
        case .roundGlasses: return "Round Glasses"
        case .sunglasses: return "Cool Shades"
        case .bowtie: return "Bow Tie"
        case .scarf: return "Knit Scarf"
        case .sweatband: return "Focus Band"
        case .starClip: return "Star Clip"
        }
    }
}

enum EffectStyle: String, CaseIterable, Codable, Identifiable {
    case none, sparkles, hearts, bubbles, aura, notes, orbit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .sparkles: return "Twinkles"
        case .hearts: return "Floating Hearts"
        case .bubbles: return "Bubbles"
        case .aura: return "Calm Aura"
        case .notes: return "Lo-fi Notes"
        case .orbit: return "Orbiting Stars"
        }
    }
}

enum DecorStyle: String, CaseIterable, Codable, Identifiable {
    case none, plant, books, mug, lamp, mushroom, crystal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .plant: return "Desk Plant"
        case .books: return "Book Stack"
        case .mug: return "Cocoa Mug"
        case .lamp: return "Little Lamp"
        case .mushroom: return "Glow Shroom"
        case .crystal: return "Focus Crystal"
        }
    }
}

struct BrainAppearance: Codable, Equatable {
    var color: BodyColor = .bubblegum
    var hat: HatStyle = .none
    var accessory: AccessoryStyle = .none
    var effect: EffectStyle = .none
    var decor: DecorStyle = .none
    var style: ExpressionStyle = .classic
}
