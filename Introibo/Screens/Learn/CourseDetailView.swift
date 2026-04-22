import SwiftUI

// A single Latin lesson, opened as a sheet. Renders the course's
// intro (drop cap) followed by each section by type: lesson/tip/
// cards/phrase/table/summary. HTML content is rendered via
// AttributedString (markdown fallback). Users can mark the lesson
// as mastered — syncs to UserProgress.

struct CourseDetailView: View {
    let course: Course
    let onMasteryChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isMastered: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        introBlock
                        ForEach(Array(course.sections.enumerated()), id: \.offset) { _, s in
                            sectionView(s)
                        }
                        masteryButton
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
            .onAppear { isMastered = UserProgress.masteredLessons().contains(course.slug) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Lésson \(roman(course.num))  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(course.title)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Text(course.latin)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
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

    // MARK: - Intro

    private var introBlock: some View {
        Text(course.intro)
            .font(.body)
            .foregroundStyle(Color.primaryText)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section dispatcher

    @ViewBuilder
    private func sectionView(_ s: Course.Section) -> some View {
        switch s.type {
        case "cards":
            cardsSection(s)
        default:
            textSection(s)
        }
    }

    private func textSection(_ s: Course.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label = s.label {
                Text(label)
                    .smallLabel(color: Color.sanctuaryRed)
            }
            if let html = s.html {
                Text(plainText(from: html))
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardsSection(_ s: Course.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label = s.label {
                Text(label)
                    .smallLabel(color: Color.sanctuaryRed)
            }
            if let note = s.note {
                Text(note)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            if let items = s.items {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, card in
                        cardRow(card)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardRow(_ c: Course.Section.Card) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(c.lat ?? "")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                if let phon = c.phon, !phon.isEmpty {
                    Text("[\(phon)]")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            if let eng = c.eng {
                Text(eng)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mastery button

    private var masteryButton: some View {
        Button {
            let newValue = !isMastered
            UserProgress.setMastered(course.slug, mastered: newValue)
            isMastered = newValue
            onMasteryChange()
        } label: {
            Text(isMastered ? "Marked as Mastered  ✠  Unmark" : "Mark as Mastered")
                .smallLabel(color: isMastered ? Color.goldLeaf : Color.sanctuaryRed, tracking: 3)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().stroke(
                    isMastered ? Color.goldLeaf.opacity(0.6) : Color.sanctuaryRed.opacity(0.6),
                    lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    // MARK: - Helpers

    /// Very light HTML-to-plain conversion. Lessons use only <p>, <strong>,
    /// <em>, and <br>. For the prototype we strip tags and normalise
    /// whitespace; proper attributed rendering is a follow-up.
    private func plainText(from html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "</p>", with: "\n\n")
        s = s.replacingOccurrences(of: "<br>", with: "\n")
        s = s.replacingOccurrences(of: "<br/>", with: "\n")
        s = s.replacingOccurrences(of: "<br />", with: "\n")
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func roman(_ n: Int) -> String {
        ["","I","II","III","IV","V","VI","VII","VIII","IX","X"][n]
    }
}
