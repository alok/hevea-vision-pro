import XCTest

@testable import FareyCore

final class ContinuedFractionTests: XCTestCase {
  func testCanonicalTruncationsDistinguishTheIntermediateMediant() throws {
    let cf = try XCTUnwrap(ContinuedFraction(Rational(3, 5)))
    XCTAssertEqual(ContinuedFraction(Rational(6, 10)), cf)
    XCTAssertEqual(cf.canonical, [0, 1, 1, 2])
    XCTAssertEqual(cf.convergents(alternate: false), [Rational(0, 1), Rational(1, 1), Rational(1, 2), Rational(3, 5)])
    XCTAssertEqual(cf.terms(alternate: true), [0, 1, 1, 1, 1])
    var state = FareyState()
    state.select(Rational(6, 10))
    XCTAssertFalse(try XCTUnwrap(state.cfPoints(alternate: false).first { $0.rational == Rational(2, 3) }).isConvergent)
    XCTAssertTrue(try XCTUnwrap(state.cfPoints(alternate: true).first { $0.rational == Rational(2, 3) }).isConvergent)
    XCTAssertEqual(state.selectedPoint, LatticePoint(p: 6, q: 10))
  }
  func testIntegersUnitFractionsAndImproperFractions() throws {
    for (p, q, terms) in [(1, 1, [1]), (3, 1, [3]), (1, 5, [0, 5]), (5, 3, [1, 1, 2]), (13, 8, [1, 1, 1, 1, 2])] {
      let cf = try XCTUnwrap(ContinuedFraction(Rational(Int64(p), Int64(q))))
      XCTAssertEqual(cf.canonical, terms.map(Int64.init))
      XCTAssertEqual(cf.convergents(alternate: false).last, Rational(Int64(p), Int64(q)))
      XCTAssertEqual(cf.convergents(alternate: true).last, Rational(Int64(p), Int64(q)))
    }
    for rational in [Rational(0, 1), Rational(1, 0), Rational(-1, 2)] { XCTAssertNil(ContinuedFraction(rational)) }
  }
  func testBothFiniteExpansionsAndEndpointWordsAcrossTheSupportedGrid() throws {
    for p in 1...30 {
      for q in 1...30 {
        var state = FareyState()
        guard state.select(Rational(Int64(p), Int64(q))) else { continue }
        let cf = try XCTUnwrap(ContinuedFraction(state.mediant))
        let endpoint = cf.terms(alternate: cf.canonical.count % 2 == 1)
        let word = endpoint.enumerated().map { index, value in
          String(repeating: index % 2 == 0 ? "L" : "R", count: Int(value))
        }.joined()
        XCTAssertEqual(word, state.word.map(\.rawValue).joined() + "R")
        for alternate in [false, true] {
          let convergents = cf.convergents(alternate: alternate)
          XCTAssertEqual(convergents.last, state.mediant)
          for (a, b) in zip(convergents, convergents.dropFirst()) {
            XCTAssertEqual(abs(a.p * b.q - a.q * b.p), 1)
          }
          XCTAssertLessThanOrEqual(state.cfPoints(alternate: alternate).count, 26)
          XCTAssertTrue(convergents.allSatisfy { c in state.cfPoints(alternate: alternate).contains { $0.rational == c } })
        }
      }
    }
  }
}
