import XCTest
@testable import ClipSafe

final class ClipSafeTests: XCTestCase {
    func testClipboardEntryCanRoundTripThroughCodable() throws {
        let entry = ClipboardEntry(
            text: "hello ClipSafe",
            copiedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: "example.app",
            isPinned: true
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ClipboardEntry.self, from: data)
        XCTAssertEqual(decoded.text, entry.text)
        XCTAssertEqual(decoded.sourceBundleID, entry.sourceBundleID)
        XCTAssertEqual(decoded.isPinned, entry.isPinned)
    }
}
