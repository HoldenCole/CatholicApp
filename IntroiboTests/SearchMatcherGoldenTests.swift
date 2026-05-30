import XCTest
@testable import Introibo

// MARK: - Cross-platform SearchMatcher parity + unit tests
//
// `testMatcherGoldenFixtures` runs SearchMatcher.search against the real
// ContentStore.shared.searchIndex for every case in search_query_golden.json
// and asserts the documented expectations. The SAME fixture file is run by the
// Android test (SearchMatcherGoldenTest.kt) — if both pass, the matcher behaves
// identically on real content.
//
// The remaining tests are pure-algorithm checks (Levenshtein, ordering) that
// require no content and pin the cross-platform behaviour.

final class SearchMatcherGoldenTests: XCTestCase {

    // MARK: Fixture model

    private struct QueryGolden: Decodable {
        let cases: [Case]
        struct Case: Decodable {
            let query: String
            let minExpectedResultCount: Int
            let mustContainDocId: String?
            let mustMatchType: String?
        }
    }

    private func loadGolden() throws -> QueryGolden {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "search_query_golden", withExtension: "json")
                ?? Bundle.main.url(forResource: "search_query_golden", withExtension: "json"),
            "search_query_golden.json not found in test or main bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(QueryGolden.self, from: data)
    }

    func testMatcherGoldenFixtures() throws {
        let golden = try loadGolden()
        XCTAssertFalse(golden.cases.isEmpty, "golden query fixture set is empty")
        let index = ContentStore.shared.searchIndex

        for c in golden.cases {
            let results = SearchMatcher.search(c.query, in: index)
            XCTAssertGreaterThanOrEqual(
                results.count, c.minExpectedResultCount,
                "query \"\(c.query)\" returned \(results.count) results, expected ≥ \(c.minExpectedResultCount)"
            )
            if let needle = c.mustContainDocId {
                XCTAssertTrue(
                    results.contains { $0.document.id.contains(needle) },
                    "query \"\(c.query)\" had no result whose id contains \"\(needle)\""
                )
            }
            if let typeRaw = c.mustMatchType {
                XCTAssertTrue(
                    results.contains { $0.document.type.rawValue == typeRaw },
                    "query \"\(c.query)\" had no result of type \"\(typeRaw)\""
                )
            }
        }
    }

    func testEmptyQueryReturnsNoResults() {
        let index = ContentStore.shared.searchIndex
        XCTAssertTrue(SearchMatcher.search("", in: index).isEmpty)
        XCTAssertTrue(SearchMatcher.search("   ", in: index).isEmpty)
    }

    // MARK: Pure Levenshtein

    func testLevenshteinDistance() {
        XCTAssertEqual(Levenshtein.distance("kitten", "sitting"), 3)
        XCTAssertEqual(Levenshtein.distance("", "abc"), 3)
        XCTAssertEqual(Levenshtein.distance("abc", "abc"), 0)
        XCTAssertEqual(Levenshtein.distance("flaw", "lawn"), 2)
    }

    func testLevenshteinIsWithin() {
        XCTAssertTrue(Levenshtein.isWithin("kyrie", "kirie", maxDistance: 1))
        XCTAssertFalse(Levenshtein.isWithin("kyrie", "abcde", maxDistance: 1))
        XCTAssertTrue(Levenshtein.isWithin("magnificat", "magnficat", maxDistance: 2))
        XCTAssertFalse(Levenshtein.isWithin("magnificat", "mag", maxDistance: 2))
    }

    // MARK: Ordering on a synthetic index

    /// Title hits must out-rank body-only hits regardless of document order.
    func testTitleHitsRankAboveBodyHits() {
        let bodyOnly = SearchDocument(
            id: "prayer:body", type: .prayer, title: "Some Other Title", subtitle: nil,
            displayText: "gloria patri et filio", searchText: "gloria patri et filio",
            target: DeepLinkTarget(type: .prayer, id: "body", position: nil)
        )
        let titleHit = SearchDocument(
            id: "prayer:title", type: .prayer, title: "Gloria", subtitle: nil,
            displayText: "ut supra", searchText: "gloria",
            target: DeepLinkTarget(type: .prayer, id: "title", position: nil)
        )
        var index = SearchIndex()
        index.replacePartition("test", [bodyOnly, titleHit]) // body first in order

        let results = SearchMatcher.search("gloria", in: index)
        XCTAssertEqual(results.first?.document.id, "prayer:title",
                       "title hit should rank first despite appearing later in document order")
        XCTAssertEqual(results.count, 2)
    }

    func testSubstringPartialMatch() {
        let doc = SearchDocument(
            id: "prayer:m", type: .prayer, title: "Magnificat", subtitle: nil,
            displayText: "Magnificat anima mea Dominum", searchText: "magnificat anima mea dominum",
            target: DeepLinkTarget(type: .prayer, id: "m", position: nil)
        )
        var index = SearchIndex()
        index.replacePartition("test", [doc])
        XCTAssertEqual(SearchMatcher.search("magn", in: index).count, 1)
    }

    func testTypeFilter() {
        let prayer = SearchDocument(
            id: "prayer:x", type: .prayer, title: "Ave", subtitle: nil,
            displayText: "Ave Maria", searchText: "ave maria",
            target: DeepLinkTarget(type: .prayer, id: "x", position: nil)
        )
        let saint = SearchDocument(
            id: "saint:y", type: .saint, title: "Ave", subtitle: nil,
            displayText: "Ave Maria", searchText: "ave maria",
            target: DeepLinkTarget(type: .saint, id: "y", position: nil)
        )
        var index = SearchIndex()
        index.replacePartition("test", [prayer, saint])
        let onlyPrayers = SearchMatcher.search("ave", in: index, typeFilter: .prayer)
        XCTAssertEqual(onlyPrayers.count, 1)
        XCTAssertEqual(onlyPrayers.first?.document.type, .prayer)
    }
}
