import XCTest
@testable import HeroNets
import Interpreter
import DDKit

final class ComputeStateSpaceTests0: XCTestCase {

  let x = ILang.var("$x")
  let y = ILang.var("$y")
  
  typealias Guard = Pair<ILang, ILang>
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<Val>

    case p1,p2,p3
  }

  enum T: Transition {
    case t1,t2
  }

  typealias KeyMarking = P
  typealias ValueMarking = Multiset<Val>

//  typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
//  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>

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


  func testComputeStateSpace0() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x]),
      .pre(from: .p2, to: .t2, labeled: [y]),
      .post(from: .t1, to: .p3, labeled: [x]),
      .post(from: .t2, to: .p3, labeled: [y]),
      guards: [.t1: nil, .t2: nil],
      interpreter: interpreter
    )

    var l: [String] = []

    for i in 1 ..< 10 {
      l.append("\(i)")
    }

    let marking = Marking<P>([.p1: ["1"], .p2: ["3", "4"], .p3: []])
//    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    let markings = model.computeStateSpaceBF(from: marking)
    
    XCTAssertEqual(markings.count, 8)
//    for m in markings {
//      print(simplifyMarking(marking: m))
//    }
  }

  func testComputeStateSpace1() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x]),
      .pre(from: .p2, to: .t2, labeled: [y]),
      .post(from: .t1, to: .p3, labeled: [x]),
      .post(from: .t2, to: .p3, labeled: [y]),
      guards: [.t1: nil, .t2: nil],
      interpreter: interpreter
    )

    var l: Multiset<Val> = []
    
    for i in 1 ..< 6 {
      l.insert(Val(stringLiteral: String(i)))
    }

    let s: Stopwatch = Stopwatch()

    let marking = Marking<P>([.p1: l, .p2: l, .p3: []])
    let markings = model.computeStateSpaceBF(from: marking)
//    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    
    print(s.elapsed.humanFormat)

    print(markings.count)
//    XCTAssertEqual(markings.count, 8)
//    for m in markings {
//      print(simplifyMarking(marking: m))
//    }
  }
  
  func testComputeStateSpace2() {
    enum P: Place, Hashable, Comparable {
      typealias Content = Multiset<Val>

      case p1,p2,p3,p4
    }

    enum T: Transition {
      case t1,t2
    }

    typealias KeyMarking = P
    typealias ValueMarking = Multiset<Val>
    typealias MarkingMFDD = MFDD<KeyMarking, ValueMarking>
    typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x]),
      .pre(from: .p3, to: .t2, labeled: [x]),
      .post(from: .t1, to: .p2, labeled: [x]),
      .post(from: .t2, to: .p4, labeled: [x]),
      guards: [.t1: nil, .t2: nil],
      interpreter: interpreter
    )
    
    let markingMFDDFactory = MarkingMFDDFactory()
    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: [], .p3: ["1", "2", "3"], .p4: []])
    
    XCTAssertEqual(64, model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory).count)
  }

  static var allTests = [
//    ("testIsFireable", testIsFireable),
    ("testComputeStateSpace0", testComputeStateSpace0),
  ]
}
