import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class BaselineOptimizedTests: XCTestCase {
  
  typealias Label = String
  typealias Value = String
  
  enum P: Place, Equatable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1
  }
  
  
  func testBinding0() {
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Pair<String, String>]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .pre(from: .p3, to: .t1, labeled: ["$x"]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let baseline = Baseline(heroNet: model)
    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "4", "5"], .p3: ["1", "2", "4"]])

    let res = baseline.bindingBruteForceWithOptimizedNet(transition: .t1, marking: marking)
    
    let expectedRes: Set<[String:String]> = [["$y": "3", "$x": "2"], ["$x": "1", "$y": "3"], ["$x": "2", "$y": "1"], ["$y": "2", "$x": "1"]]
    XCTAssertEqual(res, expectedRes)
  }
  
  // Conditions + same variables + constant + independant variable + constant propagation
  func testBinding1() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """
    
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair("$x","$y-1"), Pair("$y", "$z"), Pair("$a", "1")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$z", "$a"]),
      .pre(from: .p3, to: .t1, labeled: ["$b", "3"]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "3", "4"], .p3: ["1", "3"]])
    let baseline = Baseline(heroNet: model)
    let bindings = baseline.bindingBruteForceWithOptimizedNet(transition: .t1, marking: marking)
    
    let expectedRes = Set([["$x": "1", "$b": "1", "$z": "2"], ["$b": "1", "$x": "2", "$z": "3"]])
    
    XCTAssertEqual(bindings, expectedRes)
  }
  
  
  func testFireForAllBinding0() {
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "1","3"], .p2: ["1", "1", "2"], .p3: []])
    let baseline = Baseline(heroNet: model)
    let markings1 = baseline.fireForAllBindings(transition: .t1, from: marking, net: baseline.heroNet)

    XCTAssertEqual(markings1.count, 4)
  }
  
  func testComputeStateSpace0() {
    enum P: Place, Hashable, Comparable {
      typealias Content = Multiset<String>
      case p1,p2
    }

    enum T: Transition {
      case t1,t2
    }

    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p2, labeled: ["$x", "$x"]),
      .pre(from: .p2, to: .t2, labeled: ["$x", "$x"]),
      .post(from: .t2, to: .p1, labeled: ["$x"]),
      guards: [.t1: nil, .t2: nil],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1","2","3"], .p2: []])
    let baseline = Baseline(heroNet: model)
    let markings = baseline.CSSBruteForceWithOptimizedNet(marking: marking)

    print(markings.count)
    
    XCTAssertEqual(markings.count, 8)
  }
  
  func testComputeStateSpace1() {
    enum P: Place, Hashable, Comparable {
      typealias Content = Multiset<String>
      
      case s0,s1,op,s2,num
    }
    
    enum T: Transition {
      case t0, t1, c, tapply
    }

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
      .pre(from: .s0, to: .t0, labeled: ["1"]),
      .pre(from: .num, to: .t0, labeled: ["$x"]),
      .post(from: .t0, to: .s1, labeled: ["$x"]),
//      .post(from: .t0, to: .num, labeled: ["$x"]),
      // Transition c
      .pre(from: .s1, to: .c, labeled: ["$x"]),
      .post(from: .c, to: .s0, labeled: ["1"]),
      // Transition t1
      .pre(from: .s1, to: .t1, labeled: ["$x"]),
      .pre(from: .op, to: .t1, labeled: ["$f"]),
      .post(from: .t1, to: .s2, labeled: ["$f($x)"]),
      .post(from: .t1, to: .op, labeled: ["$f"]),
      // Transition tapply
      .pre(from: .s2, to: .tapply, labeled: ["$f"]),
      .pre(from: .num, to: .tapply, labeled: ["$x"]),
      .post(from: .tapply, to: .s1, labeled: ["$f($x)"]),
//      .post(from: .tapply, to: .num, labeled: ["$x"]),
      guards: [.t0: nil, .t1: nil, .c: nil, .tapply: nil],
      interpreter: interpreter
    )
    
    var marking = Marking<P>([.s0: ["1"], .s1: [], .s2: [], .num: ["0","1"], .op: ["add","sub"]])
    let baseline = Baseline(heroNet: model)
    var markings = baseline.CSSBruteForceWithOptimizedNet(marking: marking)

    XCTAssertEqual(markings.count, 19)

    marking = Marking<P>([.s0: ["1"], .s1: [], .s2: [], .num: ["2","3","4","5"], .op: ["sub","mul","add","div"]])

    let s = Stopwatch()
    markings = baseline.CSSBruteForceWithOptimizedNet(marking: marking)
    print(s.elapsed.humanFormat)
    print(markings.count)

    XCTAssertEqual(markings.count, 1186)
    
  }
  
}

