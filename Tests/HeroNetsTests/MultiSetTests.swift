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
  
  func testFilterInclude() {
    let m1: Multiset<String> = ["a", "a", "b", "b", "c"]
    let m2: Multiset<String> = ["a", "b", "b"]
    let res1: Multiset<String> = ["a", "a", "b", "b"]
    let res2: Multiset<String> = ["a", "b", "b"]
    
    XCTAssertEqual(m1.filterInclude(m2), res1)
    XCTAssertEqual(m2.filterInclude(m1), res2)
 
  }
  
  func testMultiset() {
    let m1: Multiset<String> = []
    let m2: Multiset<String> = ["a", "a", "b", "b", "c"]
    var m3: Multiset<String> = ["a", "a", "b", "b", "c"]
    let m4: Multiset<String> = ["a", "c", "d"]
    let m5: Multiset<String> = ["a", "a", "b", "b", "c", "d"]
    let m6: Multiset<String> = ["a", "a", "a", "b", "b", "c", "c", "d"]
    let m7: Multiset<String> = [ "a","b", "b"]
    let m8: Multiset<String> = ["a", "c"]
    let d1: Multiset<String> = ["a": 2, "b": 2, "c": 1]
    
    XCTAssertEqual(m1.multisetToArray(), [])
    XCTAssertEqual(m2.multisetToArray().sorted(by: {$0 < $1}), ["a", "a", "b", "b", "c"])
    XCTAssertEqual(m2.count, 5)
    XCTAssertEqual(m2.distinctMembers.sorted(by: {$0 < $1}), [1,2,2])
    print(m2.union(m4))
    XCTAssertEqual(m2.union(m4), m5)
    XCTAssertEqual(m2 + m4, m6)
    XCTAssertEqual(m2.subtract(m4), m7)
    XCTAssertEqual(m2.intersection(m4), m8)
    XCTAssertEqual(m2.subtract(Array(["a", "b", "b"])), m8)
    XCTAssertEqual(m2 - m7, m8)
    XCTAssertEqual(m2, d1)
    
    var s1: Set<String> = []
    for el in m2 {
      s1.insert(el)
    }
    XCTAssertEqual(s1, Set(["a","b","c"]))
    
    m3.remove("d")
    XCTAssertEqual(m3, m2)
    
  }
  
  static var allTests = [
    ("testComparison", testComparison),
    ("testFilterInclude", testFilterInclude),
    ("testMultiset", testMultiset),
  ]
}
