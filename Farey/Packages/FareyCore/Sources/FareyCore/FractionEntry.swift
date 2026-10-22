// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum FractionEntryError: Error, Equatable, LocalizedError {
  case format, integerOverflow, zeroDenominator, nonPositive, outOfRange, pathTooLong
  public var errorDescription: String? {
    switch self {
    case .format: "Enter a fraction as p/q, such as 3/5."
    case .integerOverflow: "An integer is too large to read. Enter values from 1 to 1000."
    case .zeroDenominator: "The denominator cannot be zero. Infinity is a boundary, not a selectable fraction."
    case .nonPositive: "Choose a positive numerator and denominator. Zero and negative directions are not selectable."
    case .outOfRange: "Enter numerator and denominator from 1 to 1000. This limit is checked before reduction."
    case .pathTooLong: "This fraction needs more than 24 L/R moves. Choose a shorter path."
    }
  }
}

public struct FractionEntry: Sendable {
  public let input: Rational
  public let state: FareyState
  public var fraction: Rational { state.mediant }
  public var explanation: String {
    input == fraction
      ? "Selected \(fraction). L/R path: \(state.wordLabel)."
      : "\(input) reduces to \(fraction). L/R path: \(state.wordLabel)."
  }
  public init(_ text: String) throws {
    let parts = text.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2 else { throw FractionEntryError.format }
    let p = try Self.integer(String(parts[0]))
    let q = try Self.integer(String(parts[1]))
    guard q != 0 else { throw FractionEntryError.zeroDenominator }
    guard p > 0, q > 0 else { throw FractionEntryError.nonPositive }
    guard p <= 1000, q <= 1000 else { throw FractionEntryError.outOfRange }
    var candidate = FareyState()
    guard candidate.select(Rational(p, q)) else { throw FractionEntryError.pathTooLong }
    input = Rational(p, q)
    state = candidate
  }
  private static func integer(_ text: String) throws -> Int64 {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.hasPrefix("-") ? trimmed.dropFirst() : trimmed[...]
    guard !digits.isEmpty, digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else {
      throw FractionEntryError.format
    }
    guard let value = Int64(trimmed) else { throw FractionEntryError.integerOverflow }
    return value
  }
}
