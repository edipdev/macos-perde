import XCTest
@testable import Perde

final class CommandMatcherTests: XCTestCase {
    func testSubsequenceMatchIsCaseInsensitive() {
        XCTAssertNotNil(CommandMatcher.fuzzyScore("aç", "Aç: Sistem"))
    }

    func testNonSubsequenceReturnsNil() {
        XCTAssertNil(CommandMatcher.fuzzyScore("xyz", "Aç: Sistem"))
    }

    func testPrefixContiguousMatchScoresHigherThanScattered() {
        let prefixScore = CommandMatcher.fuzzyScore("sis", "Sistem")
        let scatteredScore = CommandMatcher.fuzzyScore("sem", "Sistem")
        XCTAssertNotNil(prefixScore)
        XCTAssertNotNil(scatteredScore)
        XCTAssertGreaterThan(prefixScore!, scatteredScore!)
    }

    func testEmptyQueryMatchesAnyTitle() {
        XCTAssertNotNil(CommandMatcher.fuzzyScore("", "Aç: Sistem"))
        XCTAssertNotNil(CommandMatcher.fuzzyScore("", ""))
    }
}
