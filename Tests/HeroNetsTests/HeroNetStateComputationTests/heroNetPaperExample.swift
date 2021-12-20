import XCTest
@testable import HeroNets
import Interpreter
import DDKit

final class Calculator: XCTestCase {
  
  let x = ILang.var("$x")
  let f = ILang.var("$f")
  
  typealias Guard = Pair<ILang, ILang>
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<Val>
    
    case s0,s1,op,s2,num
  }
  
  enum T: Transition {
    case t0, t1, c, tapply
  }
  
  typealias KeyMarking = P
  typealias ValueMarking = Pair<P.Content.Key, Int>
//  typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
//  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
//  typealias Label = String
//  typealias KeyMFDDLabel = KeyMFDD<String>
//  typealias ValueMFDD = String
  
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
  
  
  func testCalculator0() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let module: String = """
    func add(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x + y

    func sub(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x - y

    func mul(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x * y

    func div(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x / y

    func eq(_ n1: Int, _ n2: Int) -> Bool ::
    // Equality between two numbers
      if n1 = n2
        then true
        else false
    """
    
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      // Transition t0
      .pre(from: .s0, to: .t0, labeled: [.val("1")]),
      .pre(from: .num, to: .t0, labeled: [x]),
      .post(from: .t0, to: .s1, labeled: [x]),
//      .post(from: .t0, to: .num, labeled: [x]),
      // Transition c
      .pre(from: .s1, to: .c, labeled: [x]),
      .post(from: .c, to: .s0, labeled: [.val("1")]),
      // Transition t1
      .pre(from: .s1, to: .t1, labeled: [x]),
      .pre(from: .op, to: .t1, labeled: [f]),
      .post(from: .t1, to: .s2, labeled: [.exp("$f($x)")]),
      .post(from: .t1, to: .op, labeled: [f]),
      // Transition tapply
      .pre(from: .s2, to: .tapply, labeled: [f]),
      .pre(from: .num, to: .tapply, labeled: [x]),
      .post(from: .tapply, to: .s1, labeled: [.exp("$f($x)")]),
//      .post(from: .tapply, to: .num, labeled: [x]),
      guards: [.t0: nil, .t1: nil, .c: nil, .tapply: nil],
      interpreter: interpreter
    )
    
    var marking = Marking<P>([.s0: ["1"], .s1: [], .s2: [], .num: ["0","1"], .op: ["add","sub"]])
//    var markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    var markings = model.computeStateSpaceAlternative(from: marking)
    
    XCTAssertEqual(markings.count, 19)

    marking = Marking<P>([.s0: ["1"], .s1: [], .s2: [], .num: ["2","3","4","5"], .op: ["sub","mul","add","div"]])
    
    let s = Stopwatch()
//    markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    markings = model.computeStateSpaceAlternative(from: marking)
    print(s.elapsed.humanFormat)
    print(markings.count)
    
    XCTAssertEqual(markings.count, 1186)
  }
  
  func testCalculator1() {
//    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
//    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let module: String = """
    func add(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x + y

    func sub(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x - y

    func mul(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x * y

    func div(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x / y

    func eq(_ n1: Int, _ n2: Int) -> Bool ::
    // Equality between two numbers
      if n1 = n2
        then true
        else false
    """
    
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      // Transition t0
      .pre(from: .s0, to: .t0, labeled: [.val("1")]),
      .pre(from: .num, to: .t0, labeled: [x]),
      .post(from: .t0, to: .s1, labeled: [x]),
//      .post(from: .t0, to: .num, labeled: [x]),
      // Transition c
      .pre(from: .s1, to: .c, labeled: [x]),
      .post(from: .c, to: .s0, labeled: [.val("1")]),
      // Transition t1
      .pre(from: .s1, to: .t1, labeled: [x]),
      .pre(from: .op, to: .t1, labeled: [f]),
      .post(from: .t1, to: .s2, labeled: [.exp("$f($x)")]),
      .post(from: .t1, to: .op, labeled: [f]),
      // Transition tapply
      .pre(from: .s2, to: .tapply, labeled: [f]),
      .pre(from: .num, to: .tapply, labeled: [x]),
      .post(from: .tapply, to: .s1, labeled: [.exp("$f($x)")]),
//      .post(from: .tapply, to: .num, labeled: [x]),
      guards: [.t0: nil, .t1: nil, .c: nil, .tapply: nil],
      interpreter: interpreter
    )
    
    var l: Multiset<Val> = []
    for i in 0 ..< 6 {
      l.insert(Val(stringLiteral: String(i)))
    }
    
    let marking = Marking<P>([.s0: ["1"], .s1: [], .s2: [], .num: l, .op: ["sub","mul","add"]])
    
    let s = Stopwatch()
//    let markings = model.computeStateSpace(from: marking, markingMFDDFactory: markingMFDDFactory)
    let markings = model.computeStateSpaceAlternative(from: marking)
    print(s.elapsed.humanFormat)
    print(markings.count)
  }
  
  static var allTests = [
    ("testCalculator0", testCalculator0),
    ("testCalculator1", testCalculator1),
  ]
}
