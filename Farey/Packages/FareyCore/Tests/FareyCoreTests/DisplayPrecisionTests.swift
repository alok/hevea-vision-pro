// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

@testable import FareyCore

final class DisplayPrecisionTests: XCTestCase {
  func testKnownDeepCollisionAndNativeRoundingBoundary() {
    let state = makeState(String(repeating: "LR", count: 12))
    XCTAssertEqual(state.mediant, Rational(121393, 75025))
    XCTAssertTrue(DisplayPrecision.diskOverlaps(state))
    for bound in [8, 10, 14] { XCTAssertTrue(DisplayPrecision.latticeOverlaps(state, bound: bound)) }
    for bound in [6, 12] { XCTAssertFalse(DisplayPrecision.latticeOverlaps(state, bound: bound)) }
    XCTAssertEqual(state.determinant, 1)
  }

  func testOrdinaryAndCloseButDistinctCoordinatesStayQuiet() {
    for word in ["", "RLR", "LRLRRRLLRLLRLLLLLRR", String(repeating: "L", count: 24),
      String(repeating: "R", count: 24)] {
      let state = makeState(word)
      XCTAssertFalse(DisplayPrecision.diskOverlaps(state), word)
      for bound in 6...14 { XCTAssertFalse(DisplayPrecision.latticeOverlaps(state, bound: bound), word) }
    }
  }

  func testInspectedMultipleDoesNotIntroduceACollision() {
    var state = FareyState()
    XCTAssertTrue(state.select(Rational(6, 10)))
    let original = state
    XCTAssertFalse(DisplayPrecision.diskOverlaps(state))
    XCTAssertFalse(DisplayPrecision.latticeOverlaps(state, bound: 12))
    XCTAssertEqual(state, original)
  }

  private func makeState(_ word: String) -> FareyState {
    var state = FareyState()
    for turn in word { XCTAssertTrue(state.step(turn == "L" ? .l : .r)) }
    return state
  }
}
