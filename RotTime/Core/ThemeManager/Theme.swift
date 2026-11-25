import SwiftUI

/// A full visual environment: background artwork, interface accents, and the
/// mascot's surroundings.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let symbol: String
    let skyTop: Color
    let skyBottom: Color
    let accent: Color
    let accent2: Color
    /// Text/icon colour used directly on top of the artwork.
    let onBackground: Color
    let prefersDarkUI: Bool
    let requirement: Requirement

    static func == (lhs: Theme, rhs: Theme) -> Bool { lhs.id == rhs.id }

    var buttonGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var ringGradient: AngularGradient {
        AngularGradient(colors: [accent2, accent, accent2], center: .center)
    }

    static let all: [Theme] = [
        Theme(id: "cozy", name: "Cozy Room", tagline: "Fairy lights, soft rug, warm cocoa.", symbol: "sofa.fill",
              skyTop: Color(hex: 0xFFE6CC), skyBottom: Color(hex: 0xF6BF97), accent: Color(hex: 0xFF8A5C), accent2: Color(hex: 0xFF5F8F),
              onBackground: Color(hex: 0x4A2C2A), prefersDarkUI: false, requirement: .free),
        Theme(id: "sunset", name: "Sunset", tagline: "Golden hour over purple hills.", symbol: "sun.horizon.fill",
              skyTop: Color(hex: 0x6C4AB6), skyBottom: Color(hex: 0xFFB86B), accent: Color(hex: 0xFF7A59), accent2: Color(hex: 0xC2459B),
              onBackground: .white, prefersDarkUI: true, requirement: .free),
        Theme(id: "minimal", name: "Minimal", tagline: "Quiet paper tones. Nothing extra.", symbol: "circle.lefthalf.filled",
              skyTop: Color(hex: 0xF6F3EE), skyBottom: Color(hex: 0xE9E3DA), accent: Color(hex: 0x3E3A5C), accent2: Color(hex: 0x7A6FD0),
              onBackground: Color.primary, prefersDarkUI: false, requirement: .free),
        Theme(id: "ocean", name: "Ocean", tagline: "Sun rays, bubbles and swaying kelp.", symbol: "water.waves",
              skyTop: Color(hex: 0x86DCF2), skyBottom: Color(hex: 0x1C6FA8), accent: Color(hex: 0x1FB5D6), accent2: Color(hex: 0x3D7BEA),
              onBackground: .white, prefersDarkUI: true, requirement: .focusMinutes(60)),
        Theme(id: "forest", name: "Forest", tagline: "Fireflies between whispering pines.", symbol: "tree.fill",
              skyTop: Color(hex: 0xD5F2DC), skyBottom: Color(hex: 0x4E9E6B), accent: Color(hex: 0x3BAA66), accent2: Color(hex: 0x1F7F6B),
              onBackground: Color(hex: 0x163B2C), prefersDarkUI: false, requirement: .streak(3)),
        Theme(id: "space", name: "Space", tagline: "Ringed planets and shooting stars.", symbol: "moon.stars.fill",
              skyTop: Color(hex: 0x0B0A26), skyBottom: Color(hex: 0x33206A), accent: Color(hex: 0x8C7BFF), accent2: Color(hex: 0xE266FF),
              onBackground: .white, prefersDarkUI: true, requirement: .sessions(10)),
        Theme(id: "candy", name: "Candy World", tagline: "Lollipop hills and sprinkle rain.", symbol: "birthday.cake.fill",
              skyTop: Color(hex: 0xFFE0F0), skyBottom: Color(hex: 0xFFC3DE), accent: Color(hex: 0xFF5FA8), accent2: Color(hex: 0xA46BFF),
              onBackground: Color(hex: 0x6B2350), prefersDarkUI: false, requirement: .points(300)),
        Theme(id: "winter", name: "Winter", tagline: "Fresh snow on sleepy mountains.", symbol: "snowflake",
              skyTop: Color(hex: 0xCFE3F7), skyBottom: Color(hex: 0xF5FAFF), accent: Color(hex: 0x4A90E2), accent2: Color(hex: 0x6FC3DF),
              onBackground: Color(hex: 0x1E3A5F), prefersDarkUI: false, requirement: .sessions(25)),
        Theme(id: "neon", name: "Neon City", tagline: "Synth skyline on a glowing grid.", symbol: "building.2.fill",
              skyTop: Color(hex: 0x120A2A), skyBottom: Color(hex: 0x4A0F6B), accent: Color(hex: 0xFF3DC8), accent2: Color(hex: 0x29E0FF),
              onBackground: .white, prefersDarkUI: true, requirement: .focusMinutes(500)),
        Theme(id: "dream", name: "Dream World", tagline: "Drifting clouds under a candy moon.", symbol: "cloud.moon.fill",
              skyTop: Color(hex: 0x2B2557), skyBottom: Color(hex: 0xE9A8D8), accent: Color(hex: 0xB28CFF), accent2: Color(hex: 0xFF8CC6),
              onBackground: .white, prefersDarkUI: true, requirement: .streak(7)),
    ]

    static func with(id: String) -> Theme { all.first { $0.id == id } ?? all[0] }
}
