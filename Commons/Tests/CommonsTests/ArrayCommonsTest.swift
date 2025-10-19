/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Nimble
import XCTest

@testable import Commons

private class DummyToken: Comparable {
  static func == (left: DummyToken, right: DummyToken) -> Bool {
    left.value == right.value
  }

  static func < (left: DummyToken, right: DummyToken) -> Bool {
    left.value < right.value
  }

  let value: String

  init(_ value: String) {
    self.value = value
  }
}

class ArrayCommonsTest: XCTestCase {
  func testTuplesToDict() {
    let tuples = [
      (1, "1"),
      (2, "2"),
      (3, "3"),
    ]
    expect(tuplesToDict(tuples)).to(equal(
      [
        1: "1",
        2: "2",
        3: "3",
      ]
    ))
  }

  func testToDict() {
    let array = [1, 2, 3]
    expect(array.toDict { "\($0)" })
      .to(equal(
        [
          1: "1",
          2: "2",
          3: "3",
        ]
      ))
  }

  func testSubstituting1() {
    let substitute = [
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let array = [
      DummyToken("b0"),
      DummyToken("b1"),
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("b4"),
      DummyToken("a2"),
    ]

    let result = array.substituting(elements: substitute)

    expect(result[2]).to(beIdenticalTo(substitute[0]))
    expect(result[3]).to(beIdenticalTo(substitute[1]))
    expect(result[5]).to(beIdenticalTo(substitute[2]))

    expect(result).to(equal(array))
  }

  func testSubstituting2() {
    let substitute = [
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let array = [
      DummyToken("a0"),
      DummyToken("b0"),
      DummyToken("a1"),
      DummyToken("b1"),
      DummyToken("a2"),
      DummyToken("b4"),
    ]

    let result = array.substituting(elements: substitute)

    expect(result[0]).to(beIdenticalTo(substitute[0]))
    expect(result[2]).to(beIdenticalTo(substitute[1]))
    expect(result[4]).to(beIdenticalTo(substitute[2]))

    expect(result).to(equal(array))
  }

  func testSubstituting3() {
    let substitute = [
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let array = [
      DummyToken("b0"),
      DummyToken("b1"),
      DummyToken("b4"),
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let result = array.substituting(elements: substitute)

    expect(result[3]).to(beIdenticalTo(substitute[0]))
    expect(result[4]).to(beIdenticalTo(substitute[1]))
    expect(result[5]).to(beIdenticalTo(substitute[2]))

    expect(result).to(equal(array))
  }

  func testSubstituting4() {
    let substitute = [
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let array = [
      DummyToken("a0"),
      DummyToken("a1"),
      DummyToken("a2"),
      DummyToken("b0"),
      DummyToken("b1"),
      DummyToken("b4"),
    ]

    let result = array.substituting(elements: substitute)

    expect(result[0]).to(beIdenticalTo(substitute[0]))
    expect(result[1]).to(beIdenticalTo(substitute[1]))
    expect(result[2]).to(beIdenticalTo(substitute[2]))

    expect(result).to(equal(array))
  }

  func testSubstituting5() {
    let substitute = [
      DummyToken("a0"),
      DummyToken("something else"),
      DummyToken("a1"),
      DummyToken("a2"),
    ]

    let array = [
      DummyToken("a0"),
      DummyToken("b0"),
      DummyToken("a1"),
      DummyToken("b1"),
      DummyToken("a2"),
      DummyToken("b4"),
    ]

    let result = array.substituting(elements: substitute)

    expect(result[0]).to(beIdenticalTo(substitute[0]))
    expect(result[2]).to(beIdenticalTo(substitute[2]))
    expect(result[4]).to(beIdenticalTo(substitute[3]))

    expect(result).to(equal(array))
  }
}
