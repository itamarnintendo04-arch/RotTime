import SwiftUI

struct CustomizationView: View {
    enum Section: Hashable {
        case themes
        case cosmetic(CosmeticCategory)
        var title: String {
            switch self {
            case .themes: return "Themes"
            case .cosmetic(let c): return c.title
            }
        }
        var symbol: String {
            switch self {
            case .themes: return "photo.fill"
            case .cosmetic(let c): return c.symbol
            }
        }
    }

    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var section: Section = .themes
    @State private var previewTheme: Theme?
    @State private var previewExpression: BrainExpression = .happy
    @State private var lockedMessage: String?

    private var sections: [Section] { [.themes] + CosmeticCategory.allCases.map { .cosmetic($0) } }
    private var shownTheme: Theme { previewTheme ?? app.theme }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                sectionPicker
                ScrollView {
                    content
                        .padding(RTSpacing.l)
                        .padding(.bottom, 20)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
            .alert("Locked", isPresented: Binding(get: { lockedMessage != nil }, set: { if !$0 { lockedMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(lockedMessage ?? "") }
        }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack(alignment: .bottom) {
            ThemeBackgroundView(theme: shownTheme, animated: app.profile.ambientAnimations)
                .frame(height: 260)
                .clipped()
            BrainCharacterView(expression: previewExpression, appearance: app.appearance, size: 220)
                .padding(.bottom, 4)
                .onTapGesture {
                    let options: [BrainExpression] = [.happy, .wink, .love, .surprised, .proud]
                    previewExpression = options.filter { $0 != previewExpression }.randomElement() ?? .happy
                    Haptics.tap(app.profile.hapticsEnabled)
                }
            if let previewTheme, !app.isUnlocked(previewTheme) {
                Label(previewTheme.requirement.text, systemImage: "lock.fill")
                    .font(RTFont.caption(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(.thickMaterial))
                    .padding(.bottom, 10)
            }
        }
        .frame(height: 260)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections, id: \.self) { s in
                    Chip(title: s.title, symbol: s.symbol, selected: section == s, tint: app.theme.accent) {
                        withAnimation(.snappy) { section = s }
                        Haptics.selection(app.profile.hapticsEnabled)
                    }
                }
            }
            .padding(.horizontal, RTSpacing.l)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch section {
        case .themes: themesGrid
        case .cosmetic(let category):
            VStack(alignment: .leading, spacing: RTSpacing.l) {
                cosmeticGrid(category)
                if category == .expression { animationGallery }
            }
        }
    }

    private var themesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(Theme.all) { theme in
                let unlocked = app.isUnlocked(theme)
                Button {
                    previewTheme = theme
                    if unlocked {
                        app.profile.themeID = theme.id
                        Haptics.success(app.profile.hapticsEnabled)
                    } else {
                        Haptics.warning(app.profile.hapticsEnabled)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            ThemeBackgroundView(theme: theme, animated: false)
                                .frame(height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    BrainCharacterView(expression: .idle, appearance: app.appearance, size: 84, animated: false, showDecor: false)
                                        .offset(y: 18)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            if app.profile.themeID == theme.id {
                                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.white, theme.accent).padding(8)
                            } else if !unlocked {
                                Image(systemName: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    .padding(7).background(Circle().fill(.black.opacity(0.45))).padding(8)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(app.profile.themeID == theme.id ? theme.accent : .clear, lineWidth: 3))
                        Text(theme.name).font(RTFont.label(.bold)).foregroundStyle(.primary)
                        Text(unlocked ? theme.tagline : theme.requirement.text)
                            .font(RTFont.caption(.medium)).foregroundStyle(.secondary).lineLimit(2)
                        if !unlocked {
                            ProgressBar(progress: theme.requirement.progress(app.snapshot), tint: theme.accent, height: 6)
                        }
                    }
                }
                .buttonStyle(BouncyButtonStyle(scale: 0.97))
            }
        }
    }

    private func isEquipped(_ item: CosmeticItem) -> Bool {
        let a = app.appearance
        switch item.category {
        case .color: return a.color.rawValue == item.rawValue
        case .hat: return a.hat.rawValue == item.rawValue
        case .accessory: return a.accessory.rawValue == item.rawValue
        case .effect: return a.effect.rawValue == item.rawValue
        case .decor: return a.decor.rawValue == item.rawValue
        case .expression: return a.style.rawValue == item.rawValue
        }
    }

    private func applying(_ item: CosmeticItem, to base: BrainAppearance) -> BrainAppearance {
        var a = base
        switch item.category {
        case .color: a.color = BodyColor(rawValue: item.rawValue) ?? a.color
        case .hat: a.hat = HatStyle(rawValue: item.rawValue) ?? a.hat
        case .accessory: a.accessory = AccessoryStyle(rawValue: item.rawValue) ?? a.accessory
        case .effect: a.effect = EffectStyle(rawValue: item.rawValue) ?? a.effect
        case .decor: a.decor = DecorStyle(rawValue: item.rawValue) ?? a.decor
        case .expression: a.style = ExpressionStyle(rawValue: item.rawValue) ?? a.style
        }
        return a
    }

    private func cosmeticGrid(_ category: CosmeticCategory) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(RewardCatalog.items(in: category)) { item in
                let unlocked = app.isUnlocked(item)
                let equipped = isEquipped(item)
                Button {
                    if unlocked {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            app.appearance = applying(item, to: app.appearance)
                        }
                        previewExpression = [.happy, .wink, .proud, .love].randomElement() ?? .happy
                        Haptics.success(app.profile.hapticsEnabled)
                    } else {
                        lockedMessage = "\(item.title): \(item.requirement.text) (\(item.requirement.progressText(app.snapshot)))."
                        Haptics.warning(app.profile.hapticsEnabled)
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(equipped ? app.theme.accent.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            if category == .color, let color = BodyColor(rawValue: item.rawValue) {
                                Circle().fill(LinearGradient(colors: [color.base, color.shade], startPoint: .top, endPoint: .bottom))
                                    .overlay(Circle().strokeBorder(color.outline, lineWidth: 3))
                                    .padding(18)
                            } else {
                                BrainCharacterView(expression: .idle, appearance: applying(item, to: app.appearance), size: 92,
                                                   animated: false, showDecor: category == .decor)
                            }
                            if !unlocked {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.35))
                                Image(systemName: "lock.fill").font(.headline).foregroundStyle(.white)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(equipped ? app.theme.accent : .clear, lineWidth: 2.5))
                        Text(item.title).font(RTFont.caption(.bold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
                        if !unlocked {
                            Text(item.requirement.progressText(app.snapshot)).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(BouncyButtonStyle(scale: 0.94))
                .accessibilityLabel("\(item.title)\(equipped ? ", equipped" : "")\(unlocked ? "" : ", locked: \(item.requirement.text)")")
            }
        }
    }

    private var animationGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Animations").font(RTFont.title(18))
            Text("Tap to preview. Special ones unlock with achievements.").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(BrainExpression.allCases) { e in
                    let unlocked = app.isUnlocked(e)
                    Chip(title: e.title, symbol: unlocked ? nil : "lock.fill", selected: previewExpression == e, tint: app.theme.accent) {
                        if unlocked {
                            previewExpression = e
                        } else if let a = Achievement.all.first(where: { $0.unlocksExpression == e }) {
                            lockedMessage = "Earn the “\(a.title)” achievement to unlock this animation: \(a.detail)"
                        }
                    }
                }
            }
        }
    }
}
