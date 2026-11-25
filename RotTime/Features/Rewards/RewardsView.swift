import SwiftUI

struct RewardsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomize = false

    var body: some View {
        let snap = app.snapshot
        NavigationStack {
            ScrollView {
                VStack(spacing: RTSpacing.l) {
                    header(snap)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements").font(RTFont.title(20))
                        ForEach(Achievement.all) { achievement in
                            AchievementRow(achievement: achievement, snapshot: snap,
                                           unlockedAt: app.rewards.unlockedAchievements[achievement.id])
                        }
                    }
                    collectionSummary(snap)
                    Label("Rewards are earned only by focusing and taking care of your attention. There are no purchases, loot boxes or random drops.",
                          systemImage: "heart.fill")
                        .font(RTFont.caption(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(RTSpacing.l)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) } }
            .sheet(isPresented: $showCustomize) { CustomizationView() }
        }
    }

    private func header(_ snap: ProgressSnapshot) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(app.theme.buttonGradient)
            HStack(spacing: 8) {
                BrainCharacterView(expression: .proud, appearance: app.appearance, size: 130, showDecor: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(snap.points)").font(RTFont.display(40)).monospacedDigit()
                    Text("spark points").font(RTFont.label(.bold)).opacity(0.85)
                    Text("1 point per focus minute · 2 per shield you resist · bonuses for achievements")
                        .font(RTFont.caption(.medium)).opacity(0.8)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private func collectionSummary(_ snap: ProgressSnapshot) -> some View {
        let themesUnlocked = Theme.all.filter { $0.requirement.isMet(snap) }.count
        let itemsUnlocked = RewardCatalog.cosmetics.filter { $0.requirement.isMet(snap) }.count
        return Card {
            SectionHeader(title: "Collection", symbol: "square.grid.3x3.fill")
            VStack(spacing: 12) {
                HStack {
                    Text("Themes").font(RTFont.label(.semibold)); Spacer()
                    Text("\(themesUnlocked)/\(Theme.all.count)").font(RTFont.caption(.bold)).foregroundStyle(.secondary)
                }
                ProgressBar(progress: Double(themesUnlocked) / Double(Theme.all.count), tint: app.theme.accent)
                HStack {
                    Text("Cosmetics").font(RTFont.label(.semibold)); Spacer()
                    Text("\(itemsUnlocked)/\(RewardCatalog.cosmetics.count)").font(RTFont.caption(.bold)).foregroundStyle(.secondary)
                }
                ProgressBar(progress: Double(itemsUnlocked) / Double(RewardCatalog.cosmetics.count), tint: app.theme.accent2)
                SecondaryButton(title: "Open wardrobe", symbol: "tshirt.fill", tint: app.theme.accent) { showCustomize = true }
            }
            .padding(.top, RTSpacing.m)
        }
    }
}

struct AchievementRow: View {
    var achievement: Achievement
    var snapshot: ProgressSnapshot
    var unlockedAt: Date?
    @EnvironmentObject private var app: AppState

    var body: some View {
        let done = unlockedAt != nil
        HStack(spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(done ? .white : .secondary)
                .frame(width: 50, height: 50)
                .background(Circle().fill(done ? AnyShapeStyle(app.theme.buttonGradient) : AnyShapeStyle(Color.primary.opacity(0.07))))
                .symbolEffect(.bounce, value: done)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title).font(RTFont.label(.bold))
                    Spacer()
                    Text("+\(achievement.bonusPoints)").font(RTFont.caption(.heavy)).foregroundStyle(done ? app.theme.accent : .secondary)
                }
                Text(achievement.detail).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                if let e = achievement.unlocksExpression {
                    Label("Unlocks the “\(e.title)” animation", systemImage: "wand.and.stars").font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(app.theme.accent)
                }
                if let unlockedAt {
                    Text("Earned \(unlockedAt.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ProgressBar(progress: achievement.requirement.progress(snapshot), tint: app.theme.accent, height: 6)
                        Text(achievement.requirement.progressText(snapshot)).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .opacity(done ? 1 : 0.92)
    }
}
