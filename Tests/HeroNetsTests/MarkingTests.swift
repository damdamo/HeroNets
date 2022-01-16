import XCTest
@testable import HeroNets
import Interpreter
import DDKit


final class MarkingTests: XCTestCase {
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  // Transform mfdd into a marking, i.e. a dictionnary with all values for each place.
  func simplifyMarking(marking: MFDD<P, Pair<String, Int>>) -> [String: Multiset<String>] {
    
    var bindingSimplify: [String: Multiset<String>] = [:]
    var setPairPerPlace: [P: Set<Pair<String,Int>>] = [:]
    
    for place in P.allCases {
      bindingSimplify["\(place)"] = []
      setPairPerPlace[place] = []
    }
    
    for el in marking {
      for (k,v) in el {
        setPairPerPlace[k]!.insert(v)
      }
    }
    
    for (place, values) in setPairPerPlace {
      for value in values {
        bindingSimplify["\(place)"]!.insert(value.l, occurences: value.r)
      }
    }
    
    return bindingSimplify
  }
  
  func testMarking() {
    
    let marking1 = Marking<P>([.p1: ["1", "2"], .p2: ["3"], .p3: ["4","5"]])
    let marking2 = Marking<P>([.p1: ["6", "7"], .p2: ["8"], .p3: ["9","10"]])
    let marking3 = Marking<P>([.p1: ["1"], .p2: [], .p3: ["4"]])
    let marking4 = Marking<P>([.p1: ["1", "1"], .p2: [], .p3: ["4","4"]])
    let marking3Bis = Marking<P>([.p1: ["1", "1"], .p2: ["2"], .p3: ["4", "4"]])
    let marking3Second = Marking<P>([.p1: ["1", "1"], .p2: [], .p3: ["4", "4"]])
    

    XCTAssertEqual(marking1 < marking1, false)
    XCTAssertEqual(marking1 > marking1, false)
    XCTAssertEqual(marking1 <= marking1, true)
    XCTAssertEqual(marking1 >= marking1, true)
    
    XCTAssertEqual(marking1 < marking2, false)
    XCTAssertEqual(marking1 > marking2, false)
    XCTAssertEqual(marking1 <= marking2, false)
    XCTAssertEqual(marking1 >= marking2, false)
    
    XCTAssertEqual(marking3 < marking4, false)
    XCTAssertEqual(marking3 > marking4, false)
    XCTAssertEqual(marking3 <= marking4, true)
    XCTAssertEqual(marking3 >= marking4, false)
    
    XCTAssertEqual(marking3Bis > marking3, true)
    XCTAssertEqual(marking3Bis < marking3, false)
    
    XCTAssertEqual(marking3Second > marking3, false)
    XCTAssertEqual(marking3Second < marking3, false)
    
    let tm: TotalMap<P, P.Content>  = [.p1: ["1", "2"], .p2: ["3"], .p3: ["4","5"]]
    let marking5 = Marking(tm)
    var marking6 = Marking<P>([.p1: ["1", "2"], .p2: ["3"], .p3: ["4","5"]])
    XCTAssertEqual(marking1, marking5)
    XCTAssertEqual(marking6[.p1], ["1", "2"])
    XCTAssertEqual(marking6.places, [.p1, .p2, .p3])
    marking6[.p1] = ["3"]
    XCTAssertEqual(marking6[.p1], ["3"])
    
    let dic: [P: P.Content] = [.p1: ["1", "2"], .p2: ["3"], .p3: ["4","5"]]
    XCTAssertEqual(Marking(dic), marking1)
    
    let marking7 = Marking<P>(partial: [.p1: ["1"], .p3: ["4"]])
    XCTAssertEqual(marking7, marking3)
    
    let marking8 = Marking<P>([.p1: [], .p2: [], .p3: []])
    XCTAssertEqual(marking8, Marking.zero)
    
    var marking9 = Marking<P>([.p1: ["1"], .p2: [], .p3: ["4"]])
    let marking10 = Marking<P>([.p1: ["3"], .p2: ["4"], .p3: ["6"]])
    marking9 += marking10
    
    var expectedRes = Marking<P>([.p1: ["1", "3"], .p2: ["4"], .p3: ["4", "6"]])
    XCTAssertEqual(marking9, expectedRes)
    
    expectedRes = Marking<P>([.p1: ["1"], .p2: [], .p3: ["4"]])
    marking9 -= marking10
    XCTAssertEqual(marking9, expectedRes)

  }
  

  static var allTests = [
    ("testMarking", testMarking),
  ]
}
