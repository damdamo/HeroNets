//import XCTest
//@testable import HeroNets
//import Interpreter
//import DDKit
//
//final class ComputeStateSpaceTests1: XCTestCase {
//
//  enum P: Place, Hashable, Comparable {
//    typealias Content = Multiset<String>
//    case p1,p2
//  }
//
//  enum T: Transition {
//    case t1,t2
//  }
//
//  typealias KeyMarking = P
//  typealias ValueMarking = Pair<P.Content.Key, Int>
//  typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
//  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
//
//  // Transform mfdd into a marking, i.e. a dictionnary with all values for each place.
//  func simplifyMarking(marking: MFDD<P, Pair<String, Int>>) -> [String: Multiset<String>] {
//
//    var bindingSimplify: [String: Multiset<String>] = [:]
//    var setPairPerPlace: [P: Set<Pair<String,Int>>] = [:]
//
//    for place in P.allCases {
//      bindingSimplify["\(place)"] = []
//      setPairPerPlace[place] = []
//    }
//
//    for el in marking {
//      for (k,v) in el {
//        setPairPerPlace[k]!.insert(v)
//      }
//    }
//
//    for (place, values) in setPairPerPlace {
//      for value in values {
//        bindingSimplify["\(place)"]!.insert(value.l, occurences: value.r)
//      }
//    }
//
//    return bindingSimplify
//  }
//
//
//  func testComputeStateSpace0() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
//
//    let interpreter = Interpreter()
////    try! interpreter.loadModule(fromString: "")
//
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x"]),
//      .post(from: .t1, to: .p2, labeled: ["$x"]),
//      .pre(from: .p2, to: .t2, labeled: ["$x"]),
//      .post(from: .t2, to: .p1, labeled: ["$x"]),
//      guards: [.t1: nil, .t2: nil],
//      interpreter: interpreter
//    )
//
//    let marking = Marking<P>([.p1: ["1","2","3"], .p2: []])
//    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
//
//    print(markings.count)
//    
//    XCTAssertEqual(markings.count, 8)
////    for m in markings {
////      print(simplifyMarking(marking: m))
////    }
//  }
//  
//  func testComputeStateSpace1() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
//
//    let interpreter = Interpreter()
////    try! interpreter.loadModule(fromString: "")
//
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x"]),
//      .post(from: .t1, to: .p2, labeled: ["$x", "$x"]),
//      .pre(from: .p2, to: .t2, labeled: ["$x", "$x"]),
//      .post(from: .t2, to: .p1, labeled: ["$x"]),
//      guards: [.t1: nil, .t2: nil],
//      interpreter: interpreter
//    )
//
//    let marking = Marking<P>([.p1: ["1","2","3"], .p2: []])
//    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
//
//    print(markings.count)
//    
//    XCTAssertEqual(markings.count, 8)
////    for m in markings {
////      print(simplifyMarking(marking: m))
////    }
//  }
//
//  static var allTests = [
////    ("testIsFireable", testIsFireable),
//    ("testComputeStateSpace0", testComputeStateSpace0),
//  ]
//}
