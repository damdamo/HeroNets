import XCTest
@testable import HeroNets
import Interpreter
import DDKit

final class AllFiringTests: XCTestCase {
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1
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
  
  
  func testFiring0() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    var marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    var res = model.fire(transition: .t1, from: marking, with: ["$x": "1", "$y": "2"], markingMFDDFactory: markingMFDDFactory)
    var expectedRes: [String: Multiset<String>] = ["p1": ["1", "2", "3"], "p2": ["1", "1"], "p3": ["3"]]
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    marking = Marking<P>([.p1: ["1"], .p2: ["2"], .p3: []])
    res = model.fire(transition: .t1, from: marking, with: ["$x": "1", "$y": "2"], markingMFDDFactory: markingMFDDFactory)
    expectedRes = ["p1": [], "p2": [], "p3": ["3"]]
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    print(simplifyMarking(marking: res))
  }
  
  
  func testFiring1() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    var model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    var marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    var res = model.fire(transition: .t1, from: marking, with: ["$x": "1", "$y": "2"], markingMFDDFactory: markingMFDDFactory)
    var expectedRes: [String: Multiset<String>] = ["p1": ["1", "3"], "p2": ["1", "1"], "p3": ["3"]]
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    res = model.fire(transition: .t1, from: marking, with: ["$x": "1", "$y": "2"], markingMFDDFactory: markingMFDDFactory)
    expectedRes = ["p1": ["1", "3"], "p2": ["1", "1"], "p3": ["3"]]
    XCTAssertEqual(simplifyMarking(marking: res), expectedRes)
    
    print(simplifyMarking(marking: res))
  }
  
  func testForAllFiring0() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    let markings1 = model.fireForAllBindings(transition: .t1, from: marking, markingMFDDFactory: markingMFDDFactory)

    XCTAssertEqual(markings1.count, 4)
    
  }
  
  func testComputeSpace0() {
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "2"], .p2: ["3", "4"], .p3: []])
    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)

    XCTAssertEqual(markings.count, 7)
//    for m in markings {
//      print(simplifyMarking(marking: m))
//    }
  }
  
  func testComputeSpace1() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p2, labeled: ["$x"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "3","4"], .p2: [], .p3: []])
    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    
//    for m in markings {
//      print(simplifyMarking(marking: m))
//    }
    XCTAssertEqual(markings.count, 16)
  }
  
  static var allTests = [
//    ("testIsFireable", testIsFireable),
    ("testFiring0", testFiring0),
    ("testFiring1", testFiring1),
  ]
}
