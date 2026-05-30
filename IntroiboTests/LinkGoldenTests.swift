import XCTest
@testable import Introibo

// MARK: - Cross-platform link parser parity tests
//
// Runs LinkTarget.parse and LinkMarkup.runs against every case in
// link_golden.json and asserts correctness. The SAME fixture file is run by
// the Android test (LinkGoldenTest.kt). If both pass, iOS and Android link
// parsing produces identical output — the parity guarantee.
//
// The fixture is loaded from the test bundle; ensure link_golden.json is a
// member of the test target's Resources (it lives in Introibo/Resources and
// is mirrored to android/app/src/test/resources).

final class LinkGoldenTests: XCTestCase {

    // MARK: - Decodable fixture shapes

    private struct Golden: Decodable {
        let parse: [ParseCase]
        let runs: [RunsCase]
    }

    private struct ParseCase: Decodable {
        let input: String
        let type: String?
        let id: String?
        let position: String?
    }

    private struct RunsCase: Decodable {
        let input: String
        let runs: [RunExpected]
    }

    private struct RunExpected: Decodable {
        let kind: String
        let text: String
        let target: String?
    }

    // MARK: - Fixture loading

    private func loadGolden() throws -> Golden {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "link_golden", withExtension: "json")
                ?? Bundle.main.url(forResource: "link_golden", withExtension: "json"),
            "link_golden.json not found in test or main bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Golden.self, from: data)
    }

    // MARK: - LinkTarget.parse tests

    func testParseMatchesGoldenFixtures() throws {
        let golden = try loadGolden()
        XCTAssertFalse(golden.parse.isEmpty, "parse fixture set is empty")

        for c in golden.parse {
            let result = LinkTarget.parse(c.input)

            if let expectedType = c.type, let expectedId = c.id {
                // Expect a successful parse
                let target = try XCTUnwrap(result, "parse(\"\(c.input)\") returned nil, expected success")
                XCTAssertEqual(
                    target.type.rawValue, expectedType,
                    "parse(\"\(c.input)\").type = \"\(target.type.rawValue)\", expected \"\(expectedType)\""
                )
                XCTAssertEqual(
                    target.id, expectedId,
                    "parse(\"\(c.input)\").id = \"\(target.id)\", expected \"\(expectedId)\""
                )
                XCTAssertEqual(
                    target.position, c.position,
                    "parse(\"\(c.input)\").position = \"\(target.position ?? "nil")\", expected \"\(c.position ?? "nil")\""
                )
            } else {
                // Expect parse failure
                XCTAssertNil(
                    result,
                    "parse(\"\(c.input)\") should return nil but got \(String(describing: result))"
                )
            }
        }
    }

    // MARK: - LinkMarkup.runs tests

    func testRunsMatchGoldenFixtures() throws {
        let golden = try loadGolden()
        XCTAssertFalse(golden.runs.isEmpty, "runs fixture set is empty")

        for c in golden.runs {
            let actual = LinkMarkup.runs(c.input)
            XCTAssertEqual(
                actual.count, c.runs.count,
                "runs(\"\(c.input)\") produced \(actual.count) runs, expected \(c.runs.count)"
            )

            for (i, expected) in c.runs.enumerated() {
                guard i < actual.count else { continue }

                switch actual[i] {
                case .text(let text):
                    XCTAssertEqual(expected.kind, "text",
                        "run[\(i)] of \"\(c.input)\": got .text, expected \(expected.kind)")
                    XCTAssertEqual(text, expected.text,
                        "run[\(i)] of \"\(c.input)\": text = \"\(text)\", expected \"\(expected.text)\"")

                case .link(let text, let target):
                    XCTAssertEqual(expected.kind, "link",
                        "run[\(i)] of \"\(c.input)\": got .link, expected \(expected.kind)")
                    XCTAssertEqual(text, expected.text,
                        "run[\(i)] of \"\(c.input)\": link text = \"\(text)\", expected \"\(expected.text)\"")
                    // Reconstruct the target string for comparison
                    let expectedTarget = try XCTUnwrap(expected.target,
                        "run[\(i)] of \"\(c.input)\": link run missing target in fixture")
                    var targetStr = "\(target.type.rawValue):\(target.id)"
                    if let pos = target.position {
                        targetStr += "#\(pos)"
                    }
                    XCTAssertEqual(targetStr, expectedTarget,
                        "run[\(i)] of \"\(c.input)\": target = \"\(targetStr)\", expected \"\(expectedTarget)\"")
                }
            }
        }
    }
}
