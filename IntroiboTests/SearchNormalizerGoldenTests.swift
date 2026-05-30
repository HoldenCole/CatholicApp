import XCTest
@testable import Introibo

// MARK: - Cross-platform fold() parity test
//
// Runs SearchNormalizer.fold against every {input, expectedFolded} pair in
// search_golden.json and asserts equality. The SAME fixture file is run by the
// Android test (SearchNormalizerGoldenTest.kt). If both pass, iOS and Android
// fold() produce identical output on the fixture set — the parity guarantee.
//
// The fixture is loaded from the test bundle; ensure search_golden.json is a
// member of the test target's Resources (it lives in Introibo/Resources and is
// mirrored to android/app/src/test/resources).

final class SearchNormalizerGoldenTests: XCTestCase {

    private struct Golden: Decodable {
        let pairs: [Pair]
        struct Pair: Decodable {
            let input: String
            let expectedFolded: String
        }
    }

    private func loadGolden() throws -> Golden {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "search_golden", withExtension: "json")
                ?? Bundle.main.url(forResource: "search_golden", withExtension: "json"),
            "search_golden.json not found in test or main bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Golden.self, from: data)
    }

    func testFoldMatchesGoldenFixtures() throws {
        let golden = try loadGolden()
        XCTAssertFalse(golden.pairs.isEmpty, "golden fixture set is empty")
        for pair in golden.pairs {
            let folded = SearchNormalizer.fold(pair.input)
            XCTAssertEqual(
                folded, pair.expectedFolded,
                "fold(\"\(pair.input)\") = \"\(folded)\", expected \"\(pair.expectedFolded)\""
            )
        }
    }

    func testFoldIsIdempotent() throws {
        // Folding an already-folded string must be a no-op (query-time safety).
        let golden = try loadGolden()
        for pair in golden.pairs {
            let once = SearchNormalizer.fold(pair.input)
            let twice = SearchNormalizer.fold(once)
            XCTAssertEqual(twice, once, "fold is not idempotent for \"\(pair.input)\"")
        }
    }
}
