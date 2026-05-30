import SwiftUI

// MARK: - SearchView (Phase 2: search UI)
//
// Full-screen modal cross-content search, presented from the Today header.
// Zero-network: every result comes from the in-memory ContentStore.searchIndex
// via the pure SearchMatcher. No URLSession / analytics here.
//
// Phase 3 will wire result taps to a DeepLinkRouter; for now a tap logs the
// target and dismisses.

// MARK: - ContentType display

extension ContentType {
    /// Human label for chips and section headers.
    var displayName: String {
        switch self {
        case .prayer:    return "Prayers"
        case .missal:    return "Missal"
        case .office:    return "Office"
        case .reference: return "Reference"
        case .saint:     return "Saints"
        case .calendar:  return "Calendar"
        }
    }

    /// SF Symbol shown as the small type indicator on a result row.
    var symbolName: String {
        switch self {
        case .prayer:    return "hands.and.sparkles"
        case .missal:    return "book.closed"
        case .office:    return "clock"
        case .reference: return "text.book.closed"
        case .saint:     return "person.crop.circle"
        case .calendar:  return "calendar"
        }
    }

    /// Stable display order for grouped sections.
    static let displayOrder: [ContentType] = [.prayer, .missal, .office, .reference, .saint, .calendar]
}

// MARK: - Filter chip model

private enum SearchFilter: Hashable {
    case all
    case type(ContentType)

    var label: String {
        switch self {
        case .all: return "All"
        case .type(let t): return t.displayName
        }
    }

    var contentType: ContentType? {
        switch self {
        case .all: return nil
        case .type(let t): return t
        }
    }
}

// MARK: - SearchView

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var filter: SearchFilter = .all
    @State private var results: [SearchResult] = []
    @State private var debounceTask: Task<Void, Never>?

    private static let filters: [SearchFilter] = [
        .all,
        .type(.prayer), .type(.missal), .type(.office),
        .type(.reference), .type(.saint), .type(.calendar),
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            filterRow
            Divider()
                .overlay(Color.frameLine)
            content
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onChange(of: filter) { _, _ in runSearch() }
    }

    // MARK: Header (title field + close)

    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quaerere")
                    .smallLabel(color: Color.sanctuaryRed)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.tertiaryText)
                TextField("", text: $query, prompt:
                    Text("Search prayers, Mass, Office…")
                        .foregroundColor(Color.tertiaryText)
                )
                .font(.body)
                .foregroundStyle(Color.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: Filter chip row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.filters, id: \.self) { f in
                    let selected = (f == filter)
                    Button { filter = f } label: {
                        Text(f.label)
                            .font(.caption)
                            .foregroundStyle(selected ? Color.parchment : Color.secondaryText)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                selected ? Color.sanctuaryRed : Color.clear
                            )
                            .overlay(
                                Rectangle().stroke(
                                    selected ? Color.sanctuaryRed : Color.frameLine,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: Results / states

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyPrompt
        } else if results.isEmpty {
            noResults
        } else {
            resultsList
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("✠")
                .font(.titleL)
                .foregroundStyle(Color.sanctuaryRed)
            Text("Search the whole library")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Prayers, the Mass, the Office, reference, saints, and the calendar.")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No results")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Nihil invéntum")
                .smallLabel(color: Color.tertiaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(ContentType.displayOrder, id: \.self) { type in
                    let group = results.filter { $0.document.type == type }
                    if !group.isEmpty {
                        Text(type.displayName)
                            .smallLabel(color: Color.sanctuaryRed)
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 8)
                        ForEach(group) { result in
                            Button { selectResult(result) } label: {
                                resultRow(result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.document.type.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(Color.goldLeaf)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.document.title.strippingEm)
                    .font(.titleM)
                    .foregroundStyle(Color.primaryText)
                if let subtitle = result.document.subtitle, !subtitle.isEmpty {
                    Text(subtitle.strippingEm)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.tertiaryText)
                }
                highlightedSnippet(result.snippet)
                    .font(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.frameLine).frame(height: 0.5)
        }
    }

    /// Builds an AttributedString from the snippet, applying a sanctuary-red
    /// emphasis to each highlight range.
    private func highlightedSnippet(_ snippet: SearchSnippet) -> Text {
        var attributed = AttributedString(snippet.text)
        for range in snippet.highlightRanges {
            // Map the String.Index range into the AttributedString's index space.
            if let lower = AttributedString.Index(range.lowerBound, within: attributed),
               let upper = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[lower..<upper].foregroundColor = Color.sanctuaryRed
                attributed[lower..<upper].font = .bodySm.weight(.semibold)
            }
        }
        return Text(attributed)
    }

    // MARK: Search execution

    private func scheduleSearch() {
        debounceTask?.cancel()
        let snapshot = query
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
            if Task.isCancelled { return }
            // Only run if the query is still current.
            if snapshot == query {
                runSearch()
            }
        }
    }

    private func runSearch() {
        let index = ContentStore.shared.searchIndex
        results = SearchMatcher.search(query, in: index, typeFilter: filter.contentType)
    }

    private func selectResult(_ result: SearchResult) {
        // Phase 3: DeepLinkRouter.open(result.document.target)
        print("Search tap → \(result.document.id) target=\(result.document.target)")
        dismiss()
    }
}

#Preview { SearchView() }
