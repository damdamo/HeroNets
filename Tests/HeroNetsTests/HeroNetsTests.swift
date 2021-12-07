import XCTest
@testable import HeroNets
import Interpreter
import DDKit


final class HeroNetsTests: XCTestCase {
  
  func testIsFireable() {
    
    enum P: Place {
      typealias Content = Multiset<String>
      
      case p1,p2,p3
    }
    
    enum T: Transition {
      case t1, t2
    }
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: [Pair("$x","$z"), Pair("$x","$y-1")], .t2: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["1","2","3","4"], .p2: ["1", "1", "2", "3", "4"], .p3: []])
    
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x":"2", "$y":"3", "$z": "2"]), true)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x":"1", "$y":"4", "$z": "2"]), false)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x":"6", "$y":"4", "$z": "6"]), false)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x":"1", "$y":"2", "$z": "1"]), true)
  }
  
  // Test of a simple Hero net
  func testHeroNet1() {
    
    enum P1: Place {
      typealias Content = Multiset<String>
      case op, n, res
    }
    
    enum T1: Transition {
      case apply
    }
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    func sub(_ x: Int, _ y: Int) -> Int ::
      x - y
    func mul(_ x: Int, _ y: Int) -> Int ::
      x * y
    func div(_ x: Int, _ y: Int) -> Int ::
      x / y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P1, T1>(
      .pre(from: .op, to: .apply, labeled: ["$f"]),
      .pre(from: .n, to: .apply, labeled: ["$x","$y"]),
      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
      .post(from: .apply, to: .op, labeled: ["$f"]),
      guards: [.apply: [Pair("$f","add")]],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P1>([.op: ["add","sub","mul","div"], .n: ["1", "1", "2", "3", "4"], .res: []])
    let marking2 = Marking<P1>([.op: ["add","sub","mul","div"], .n: ["1", "2", "3"], .res: ["5"]])
    
    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["$f": "add", "$x": "1", "$y": "4"]), marking2)
    
    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["$f": "mul", "$x": "1", "$y": "4"]), nil)
  }
  
  // Test application of curryfication (partial application)
  func testHeroNet2() {
    
    enum P2: Place {
      typealias Content = Multiset<String>
      case op, p1, p2, res
    }
    
    enum T2: Transition {
      case curry, apply
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
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P2, T2>(
      .pre(from: .op, to: .curry, labeled: ["$f"]),
      .pre(from: .p1, to: .curry, labeled: ["$x"]),
      .pre(from: .p1, to: .apply, labeled: ["$y"]),
      .pre(from: .p2, to: .apply, labeled: ["$g"]),
      .post(from: .curry, to: .p2, labeled: ["$f($x)"]),
      .post(from: .apply, to: .res, labeled: ["$g($y)"]),
      guards: [.curry: nil, .apply: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["1", "1", "2", "3", "4"], .p2: [], .res: []])
    let marking1AfterFiringCurry = model.fire(transition: .curry, from: marking1, with: ["$f": "mul", "$x": "4"])
    let marking1AfterFiringCurryExpected = Marking<P2>([.op: ["add","sub","div"], .p1: ["1", "1", "2", "3"], .p2: ["mul(4)"], .res: []])
    
    XCTAssertEqual(marking1AfterFiringCurry, marking1AfterFiringCurryExpected)
    
    let marking1AfterFiringApply = model.fire(transition: .apply, from: marking1AfterFiringCurry!, with: ["$g": "mul(4)", "$y": "2"])
    let marking1AfterFiringApplyExpected = Marking<P2>([.op: ["add","sub","div"], .p1: ["1", "1", "3"], .p2: [], .res: ["8"]])
    
    XCTAssertEqual(marking1AfterFiringApply, marking1AfterFiringApplyExpected)
    
  }
  
  func testFireWithoutValuesOnPreArcs() {
    enum P3: Place {
      typealias Content = Multiset<String>
      
      case p1,p2
    }
    
    enum T3: Transition {
      case t1
    }
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P3, T3>(
      .pre(from: .p1, to: .t1, labeled: []),
      .post(from: .t1, to: .p2, labeled: ["1"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P3>([.p1: [], .p2: []])
    
    let res = model.fire(transition: .t1, from: marking1, with: [:])!
    XCTAssertEqual(res, Marking<P3>([.p1: [], .p2: ["1"]]))
  }

  static var allTests = [
    ("testIsFireable", testIsFireable),
    ("testHeroNet1", testHeroNet1),
    ("testHeroNet2", testHeroNet2),
  ]
}
