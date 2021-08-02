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
  
  func testIntersection() {
    let m1: Multiset<String> = ["a", "a", "b", "b", "c"]
    let m2: Multiset<String> = ["a", "b", "b"]
    let m3: Multiset<String> = []
    let res: Multiset<String> = ["a", "b", "b"]
    
    XCTAssertEqual(m1.intersection(m3), m3)
    XCTAssertEqual(m1.intersection(m2), res)
  }
  
  func testFilterInclude() {
    let m1: Multiset<String> = ["a", "a", "b", "b", "c"]
    let m2: Multiset<String> = ["a", "b", "b"]
    let res1: Multiset<String> = ["a", "a", "b", "b"]
    let res2: Multiset<String> = ["a", "b", "b"]
    
    XCTAssertEqual(m1.filterInclude(m2), res1)
    XCTAssertEqual(m2.filterInclude(m1), res2)
 
  }
  
  static var allTests = [
      ("testComparison", testComparison),
  ]
}
