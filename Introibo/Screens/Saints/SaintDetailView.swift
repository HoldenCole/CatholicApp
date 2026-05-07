import SwiftUI

struct SaintDetailView: View {
    let saint: Saint
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ProgressKey.followedSaint) private var followedSlug: String = ""
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @State private var streak: Int = 0
    @State private var completed: Set<String> = []

    private var isFollowed: Bool { followedSlug == saint.slug }
    private var totalPractices: Int { saint.sections.flatMap { $0.practices }.count }
    private var progress: Double { totalPractices > 0 ? Double(completed.count) / Double(totalPractices) : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        quoteBlock
                        followButton
                        if isFollowed {
                            progressCard
                        }
                        ForEach(Array(saint.sections.enumerated()), id: \.offset) { _, section in
                            sectionBlock(section)
                        }
                        if let prayers = saint.prayers, !prayers.isEmpty {
                            saintPrayersBlock(prayers)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .onAppear {
                streak = UserProgress.saintStreak(slug: saint.slug)
                completed = UserProgress.completedPractices()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Praxes Sanctorum  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(saint.name)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
            Text(saint.title)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if isFollowed && streak > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<min(streak, 7), id: \.self) { _ in
                        Circle().fill(Color.goldLeaf).frame(width: 6, height: 6)
                    }
                    if streak > 7 {
                        Text("+ \(streak - 7)")
                            .font(.captionSm)
                            .foregroundStyle(Color.goldLeaf)
                    }
                }
                .padding(.top, 6)
            }
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 60, height: 0.5)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.frameLine, lineWidth: 4)
                    .frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.sanctuaryRed, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                Text("\(completed.count)/\(totalPractices)")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
            }
            Text(progress >= 1.0 ? "Perfect day" : "Today's progress")
                .font(.captionSm)
                .italic()
                .foregroundStyle(progress >= 1.0 ? Color.goldLeaf : Color.tertiaryText)
            if streak > 0 {
                Text("\(streak) day streak")
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }

    // MARK: - Quote

    private var quoteBlock: some View {
        Text("\u{201C}\(saint.quote)\u{201D}")
            .font(.bodyIt)
            .foregroundStyle(Color.secondaryText)
            .lineSpacing(4)
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                Rectangle()
                    .fill(Color.sanctuaryRed.opacity(0.4))
                    .frame(width: 1)
                , alignment: .leading
            )
    }

    // MARK: - Follow button

    private var followButton: some View {
        Button {
            if isFollowed {
                followedSlug = ""
            } else {
                followedSlug = saint.slug
                UserProgress.bumpSaintStreak(slug: saint.slug)
                streak = UserProgress.saintStreak(slug: saint.slug)
            }
        } label: {
            Text(isFollowed ? "Unfollow" : "Follow this Saint")
                .smallLabel(color: isFollowed ? Color.secondaryText : Color.sanctuaryRed, tracking: 3)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().stroke(
                    isFollowed ? Color.secondaryText.opacity(0.4) : Color.sanctuaryRed.opacity(0.6),
                    lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section with checkboxes

    private func sectionBlock(_ section: Saint.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
                Text(section.lat)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(3)
                    .fixedSize()
                Text(".")
                    .foregroundStyle(Color.tertiaryText)
                Text(section.eng)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
            }

            ForEach(Array(section.practices.enumerated()), id: \.offset) { idx, p in
                practiceRow(p, sectionLat: section.lat, index: idx)
                if idx < section.practices.count - 1 {
                    Divider().background(Color.frameLine.opacity(0.5))
                }
            }
        }
    }

    private func practiceRow(_ p: Saint.Practice, sectionLat: String, index: Int) -> some View {
        let practiceId = "\(saint.slug).\(sectionLat).\(index)"
        let isDone = completed.contains(practiceId)

        return Button {
            if isFollowed {
                UserProgress.togglePractice(practiceId)
                completed = UserProgress.completedPractices()
                if completed.count == totalPractices {
                    UserProgress.bumpSaintStreak(slug: saint.slug)
                    streak = UserProgress.saintStreak(slug: saint.slug)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if isFollowed {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isDone ? Color.goldLeaf : Color.frameLine)
                        .font(.system(size: 20))
                        .padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.t)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(isDone ? Color.tertiaryText : Color.primaryText)
                        .strikethrough(isDone, color: Color.tertiaryText)
                    Text(p.d)
                        .font(.bodySm)
                        .foregroundStyle(isDone ? Color.tertiaryText : Color.secondaryText)
                        .lineSpacing(3)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isFollowed)
    }

    // MARK: - Saint prayers

    private func saintPrayersBlock(_ prayers: [Saint.SaintPrayer]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
                Text("Orationes")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(3)
                    .fixedSize()
                Text(".")
                    .foregroundStyle(Color.tertiaryText)
                Text("Prayers")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            }

            ForEach(prayers) { prayer in
                VStack(alignment: .leading, spacing: 8) {
                    Text(prayer.title)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)

                    if let note = prayer.note {
                        Text(note)
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.goldLeaf)
                    }

                    BilingualLine(lat: prayer.latin ?? "", eng: prayer.eng, sideBySide: true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    Rectangle()
                        .fill(Color.sanctuaryRed.opacity(0.15))
                        .frame(width: 2)
                    , alignment: .leading
                )
            }
        }
    }
}
