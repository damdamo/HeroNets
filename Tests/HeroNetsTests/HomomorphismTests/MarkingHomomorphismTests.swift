import XCTest
@testable import HeroNets
import Interpreter
import DDKit


final class MarkingHomomorphismTests: XCTestCase {
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  typealias KeyMarking = P
  typealias ValueMarking = Pair<P.Content.Key, Int>
  typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
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
  
  func testFilterExcludeMarking() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$y"]),
//      .post(from: .t1, to: .p3, labeled: ["$x"]),
//      guards: [.t1: nil, .t2: nil],
//      interpreter: interpreter
//    )
    
    let marking1 = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    
    let mfddMarking1 = marking1.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
    
    var m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("2",1)])])
    var res = m.apply(on: mfddMarking1)
    var expectedRes: [String: Multiset<String>] = ["p1": ["1": 2, "3": 1], "p2": ["1": 2, "2": 1], "p3": [:]]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("1",1)])])
    res = m.apply(on: mfddMarking1)
    expectedRes = ["p1": ["1": 1, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": [:]]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("1",2), Pair("2", 1)])])
    res = m.apply(on: mfddMarking1)
    expectedRes = ["p1": ["3": 1], "p2": ["1": 2, "2": 1], "p3": [:]]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("1",2), Pair("2", 1), Pair("3", 1)])])
    res = m.apply(on: mfddMarking1)
    expectedRes = ["p1": [:], "p2": ["1": 2, "2": 1], "p3": [:]]
    
    print(markingMFDDFactory.one.pointer)
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("1",2), Pair("2", 1)]), (key: .p2, values: [Pair("1",1)])])
    res = m.apply(on: mfddMarking1)
    expectedRes = ["p1": ["3": 1], "p2": ["1": 1, "2": 1], "p3": [:]]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("42",1)])])
    res = m.apply(on: mfddMarking1)
    expectedRes = ["p1": [], "p2": [], "p3": []]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    let marking2 = Marking<P>([.p1: ["1"], .p2: ["2"], .p3: ["3"]])
    let mfddMarking2 = marking2.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
    
    m = morphisms.filterMarking(excluding: [(key: .p1, values: [Pair("1",1)]), (key: .p2, values: [Pair("2",1)])])
    res = m.apply(on: mfddMarking2)
    expectedRes = ["p1": [:], "p2": [:], "p3": ["3"]]
    
    print(markingMFDDFactory.one.pointer)
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    
    
  }
  
  func testInsertValueInMarking() {

    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let marking0 = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])

    let mfddMarking = marking0.markingToMFDD(markingMFDDFactory: markingMFDDFactory)

    var m = morphisms.insertValueInMarking(insert: [(key: .p1, values: [Pair("2",1)])])
    var res = m.apply(on: mfddMarking)
    
    var expectedRes: [String: Multiset<String>] = ["p1": ["1": 2, "2": 2, "3": 1], "p2": ["1": 2, "2": 1], "p3": [:]]

    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)

    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42",2)])])
    res = m.apply(on: mfddMarking)
    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 2]]

    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)]), (key: .p3, values: [Pair("43", 1)])])
    res = m.apply(on: mfddMarking)
    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 1, "43": 1]]
    
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)])])
    res = m.apply(on: mfddMarking)
    res = m.apply(on: res)
    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 2]]

    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)

    
    let marking1 = Marking<P>([.p1: [], .p2: ["1", "1", "2"], .p3: []])

    let mfddMarking1 = marking1.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
    m = morphisms.insertValueInMarking(insert: [(key: .p1, values: [Pair("42", 1)])])
    res = m.apply(on: mfddMarking1)
    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)])])
    res = m.apply(on: res)
    expectedRes = ["p1": ["42": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 1]]

    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
  }
  
//  func testInsertValueInMarking() {
//
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
//
//    let marking0 = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
//
//    let mfddMarking = marking0.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
//
//    var m = morphisms.insertValueInMarking(insert: [(key: .p1, values: [Pair("2",1)])])
//    var res = m.apply(on: mfddMarking)
//    
//    var expectedRes: [String: Multiset<String>] = ["p1": ["1": 2, "2": 2, "3": 1], "p2": ["1": 2, "2": 1], "p3": [:]]
//
//    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
//
//    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42",2)])])
//    res = m.apply(on: mfddMarking)
//    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 2]]
//
//    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
//    
//    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)]), (key: .p3, values: [Pair("43", 1)])])
//    res = m.apply(on: mfddMarking)
//    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 1, "43": 1]]
//    
//    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
//    
//    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)])])
//    res = m.apply(on: mfddMarking)
//    res = m.apply(on: res)
//    expectedRes = ["p1": ["1": 2, "2": 1, "3": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 2]]
//
//    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
//
//    
//    let marking1 = Marking<P>([.p1: [], .p2: ["1", "1", "2"], .p3: []])
//
//    let mfddMarking1 = marking1.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
//    m = morphisms.insertValueInMarking(insert: [(key: .p1, values: [Pair("42", 1)])])
//    res = m.apply(on: mfddMarking1)
//    m = morphisms.insertValueInMarking(insert: [(key: .p3, values: [Pair("42", 1)])])
//    res = m.apply(on: res)
//    expectedRes = ["p1": ["42": 1], "p2": ["1": 2, "2": 1], "p3": ["42": 1]]
//
//    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
//  }
  
  static var allTests = [
    ("testFilterExcludeMarking", testFilterExcludeMarking),
    ("testInsertValueInMarking", testInsertValueInMarking),
  ]
}
