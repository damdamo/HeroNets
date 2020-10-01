import XCTest
@testable import HeroNets
import Interpreter

final class MultiSetTests: XCTestCase {
  func testComparison() {
    
    let m0: Multiset<String> = [:]
    let m1: Multiset<String> = ["a", "b"]
    let m2: Multiset<String> = ["a", "a", "b", "b"]
    let m3: Multiset<String> = ["x", "y", "z"]    
    
    XCTAssertEqual(m0 <= m0, true)
    XCTAssertEqual(m0 >= m0, true)
    XCTAssertEqual(m0 < m0, false)
    XCTAssertEqual(m0 > m0, false)
    
    XCTAssertEqual(m1 <= m1, true)
    XCTAssertEqual(m1 >= m1, true)
    XCTAssertEqual(m1 < m1, false)
    XCTAssertEqual(m1 > m1, false)
    
    XCTAssertEqual(m1 < m2, true)
    XCTAssertEqual(m1 <= m2, true)
    XCTAssertEqual(m1 > m2, false)
    XCTAssertEqual(m1 >= m2, false)
    
    XCTAssertEqual(m2 <= m3, false)
    XCTAssertEqual(m2 >= m3, false)
    XCTAssertEqual(m2 < m3, false)
    XCTAssertEqual(m2 > m3, false)
    
  }
  static var allTests = [
      ("testComparison", testComparison),
  ]
}
