import XCTest

@testable import FareyCore

final class FractionEntryTests: XCTestCase {
  func testReductionAndBoundaryPaths() throws {
    let entry = try FractionEntry(" 6 / 10 ")
    XCTAssertEqual(entry.fraction, Rational(3, 5))
    XCTAssertEqual(entry.state.wordLabel, "RLR")
    XCTAssertTrue(entry.explanation.contains("6/10 reduces to 3/5"))
    for text in ["25/1", "1/25"] {
      XCTAssertEqual(try FractionEntry(text).state.word.count, 24)
    }
    XCTAssertEqual(try FractionEntry("1000/1000").fraction, Rational(1, 1))
  }
  func testMalformedAndNonPositiveInput() {
    for text in ["", "3", "1/2/3", "1.5/2", "one/two", "/2"] {
      assertError(text, .format)
    }
    assertError("1/0", .zeroDenominator)
    for text in ["0/1", "-1/2", "1/-2", "-9223372036854775808/1"] {
      assertError(text, .nonPositive)
    }
  }
  func testBoundsAreCheckedBeforeReductionAndOverflowDoesNotTrap() {
    assertError("1001/1001", .outOfRange)
    assertError("999999999999999999999999/1", .integerOverflow)
    assertError("1/999999999999999999999999", .integerOverflow)
    for text in ["26/1", "1/26", "1/1000", "1000/1"] { assertError(text, .pathTooLong) }
  }
  private func assertError(_ text: String, _ expected: FractionEntryError) {
    XCTAssertThrowsError(try FractionEntry(text)) { error in
      XCTAssertEqual(error as? FractionEntryError, expected)
    }
  }
}
