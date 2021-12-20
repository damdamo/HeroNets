import XCTest
@testable import HeroNets
import Interpreter
import DDKit


final class HeroNetsTests: XCTestCase {
  
  let f = ILang.var("$f")
  let g = ILang.var("$g")
  let x = ILang.var("$x")
  let y = ILang.var("$y")
  let z = ILang.var("$z")
  
  func testIsFireable() {
    
    enum P: Place {
      typealias Content = Multiset<Val>
      
      case p1,p2,p3
    }
    
    enum T: Transition {
      case t1//, t2
    }
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x,y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [.exp("$x+$y")]),
      guards: [.t1: [Pair(x,z), Pair(x, .exp("$y-1"))]],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "2", "3","4"], .p2: ["1", "1", "2", "3","4"], .p3: []])

    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x": "2", "$y": "3", "$z": "2"]), true)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x": "1", "$y": "4", "$z": "2"]), false)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x": "6", "$y": "4", "$z": "6"]), false)
    XCTAssertEqual(model.isFireable(transition: .t1, from: marking1, with: ["$x": "1", "$y": "2", "$z": "1"]), true)
  }
  
  
  // Test of a simple Hero net
  func testHeroNet1() {

    enum P1: Place {
      typealias Content = Multiset<Val>
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
      .pre(from: .op, to: .apply, labeled: [f]),
      .pre(from: .n, to: .apply, labeled: [x,y]),
      .post(from: .apply, to: .res, labeled: [.exp("$f($x,$y)")]),
      .post(from: .apply, to: .op, labeled: [f]),
      guards: [.apply: [Pair(f, .val(.cst("add")))]],
      interpreter: interpreter
    )

    let op1 = Val.arrayStrToMultisetVal(["add","sub","mul","div"])
    let n1 = Val.arrayStrToMultisetVal(["1", "1", "2", "3", "4"])
    let n2 = Val.arrayStrToMultisetVal(["1", "2", "3"])
    let res = Val.arrayStrToMultisetVal(["5"])
    
    let marking1 = Marking<P1>([.op: op1, .n: n1, .res: []])
    let marking2 = Marking<P1>([.op: op1, .n: n2, .res: res])

    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["$f": .cst("add"), "$x": .cst("1"), "$y": .cst("4")]), marking2)

    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["$f": .cst("mul"), "$x": .cst("1"), "$y": .cst("4")]), nil)
  }

  
  // Test application of curryfication (partial application)
  func testHeroNet2() {

    enum P2: Place {
      typealias Content = Multiset<Val>
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
      .pre(from: .op, to: .curry, labeled: [f]),
      .pre(from: .p1, to: .curry, labeled: [x]),
      .pre(from: .p1, to: .apply, labeled: [y]),
      .pre(from: .p2, to: .apply, labeled: [g]),
      .post(from: .curry, to: .p2, labeled: [.exp("$f($x)")]),
      .post(from: .apply, to: .res, labeled: [.exp("$g($y)")]),
      guards: [.curry: nil, .apply: nil],
      interpreter: interpreter
    )
    
    let op1 = Val.arrayStrToMultisetVal(["add","sub","mul","div"])
    let p11 = Val.arrayStrToMultisetVal(["1", "1", "2", "3", "4"])

    let marking1 = Marking<P2>([.op: op1, .p1: p11, .p2: [], .res: []])
    let marking1AfterFiringCurry = model.fire(transition: .curry, from: marking1, with: ["$f": .cst("mul"), "$x": .cst("4")])
    
    let op2 = Val.arrayStrToMultisetVal(["add","sub","div"])
    let p12 = Val.arrayStrToMultisetVal(["1", "1", "2", "3"])
    
    let marking1AfterFiringCurryExpected = Marking<P2>([.op: op2, .p1: p12, .p2: [.cst("mul(4)")], .res: []])

    XCTAssertEqual(marking1AfterFiringCurry, marking1AfterFiringCurryExpected)

    let marking1AfterFiringApply = model.fire(transition: .apply, from: marking1AfterFiringCurry!, with: ["$g": .cst("mul(4)"), "$y": .cst("2")])
    
    let p13 = Val.arrayStrToMultisetVal(["1", "1", "3"])
    let marking1AfterFiringApplyExpected = Marking<P2>([.op: op2, .p1: p13, .p2: [], .res: [.cst("8")]])

    XCTAssertEqual(marking1AfterFiringApply, marking1AfterFiringApplyExpected)

  }

  
  func testFireWithoutValuesOnPreArcs() {
    enum P3: Place {
      typealias Content = Multiset<Val>

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
      .post(from: .t1, to: .p2, labeled: [.val(.cst("1"))]),
      guards: [.t1: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P3>([.p1: [], .p2: []])

    let res = model.fire(transition: .t1, from: marking1, with: [:])!
    XCTAssertEqual(res, Marking<P3>([.p1: [], .p2: [.cst("1")]]))
  }
  
  func testFireBlackToken() {
    enum P: Place {
      typealias Content = Multiset<Val>

      case p1,p2
    }

    enum T: Transition {
      case t1
    }

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [.val(.btk)]),
      .post(from: .t1, to: .p2, labeled: [.val(.btk)]),
      guards: [.t1: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: [.btk], .p2: []])

    let res = model.fire(transition: .t1, from: marking1, with: [:])!
    XCTAssertEqual(res, Marking<P>([.p1: [], .p2: [.btk]]))
  }

  static var allTests = [
    ("testIsFireable", testIsFireable),
    ("testHeroNet1", testHeroNet1),
//    ("testHeroNet2", testHeroNet2),
  ]
}
