import XCTest
@testable import HeroNets
import Interpreter

final class HeroNetsTests: XCTestCase {
  func testExample() {
      
//      typealias Place = String
////      let p1 = Place(name: "p1", values: ["1": 2, "2": 4])
////      let p2 = Place(name: "p2", values: [:])
//
//      let places: Set<Place> = ["p1","p2"]
//      let guards: [Transition.Condition] = [Transition.Condition(e1: "$x*2", e2: "y")]
//
//      let t1 = Transition(name: "t1", guards: guards, inArcs: [Transition.InArc(variables: ["x", "y"], place: "p1")], outArcs: [Transition.OutArc(expr: "add(x,y)", place: "p2")]
//      )
//
//      let transitions: Set<Transition> = [t1]
//
//      let marking: [Place: [String: Int]] = ["p1": ["2": 2, "4":1], "p2": [:]]
//
//      let module: String = """
//      func add(_ x: Int, _ y: Int) -> Int ::
//        x + y
//      """
//
//
//      var interpreter = Interpreter()
//      try! interpreter.loadModule(fromString: module)
//
//      let code: String = "add(1,2)"
//      let value = try! interpreter.eval(string: code)
//      print(value)
//      let heroNet =  HeroNet(places: places, transitions: transitions, marking: marking, interpreter: interpreter)
//
//      print(try! heroNet.transitions.first?.isFireable(marking: marking, binding: ["x":"2", "y":"4"], interpreter: interpreter))
//
//      // print(heroNet.transitions.first?.checkGuards(binding: ["x": "2", "y": "2"], interpreter: interpreter))
  }
      
  enum P: Place {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  
  func testNew() {
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p3, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p2, labeled: ["$z+5"]),
      guards: [.t1: [Condition("$x + $z","$y")], .t2: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["18", "22", "99"], .p2: ["2","2", "22"], .p3: ["1","4"]])
    let marking2 = Marking<P>([.p1: ["18", "22"], .p2: [":"], .p3: ["4"]])
//    let marking3 = Marking<P>([.p1: ["2", "2", "1"], .p2: ["2","2"], .p3: ["3"]])
//
//
//    let m1: Multiset<String> = ["x", "x", "y", "y"]
//    let m2: Multiset<String> = ["y", "y", "x", "x"]
//
//    let m3: Multiset<String> = [:]
//    let m4: Multiset<String> = ["2":2]
    
//    let m3: Multiset<String> = ["x": 2, "y": 3]
    
//    print(marking3 - marking1)
//    print(m1 > m2)
//    print(marking1 < marking3)
//    print(m3)
//
//    marking1 += marking2
//    print(marking1 + marking2)
    
    
    print(model.fire(transition: .t1, from: marking1, with: ["x": "18", "y": "22", "z": "4"]))
    
//    print(model.isFireable(transition: .t1, from: marking1, with: ["x": "18", "y": "22", "z": "4"]))
    
//    let x = TotalMap([T.t1: [("x","y"), ("x","z")], T.t2: nil])
//    print(x[.t1])
    

//    print(marking1 <= marking2)
    
  }
  
  func testIsFireable() {
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p3, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p2, labeled: ["$z+5"]),
      guards: [.t1: [Condition("$x + $z","$y")], .t2: nil],
      interpreter: interpreter
    )
  }
  
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
      .pre(from: .op, to: .apply, labeled: ["f"]),
      .pre(from: .n, to: .apply, labeled: ["x","y"]),
      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
      .post(from: .apply, to: .op, labeled: ["$f"]),
      guards: [.apply: [Condition("$f","add")]],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P1>([.op: ["add","sub","mul","div"], .n: ["1", "1", "2", "3", "4"], .res: []])
    let marking2 = Marking<P1>([.op: ["add","sub","mul","div"], .n: ["1", "2", "3"], .res: ["5"]])
    
    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["f": "add", "x": "1", "y": "4"]), marking2)
    
    XCTAssertEqual(model.fire(transition: .apply, from: marking1, with: ["f": "mul", "x": "1", "y": "4"]), nil)
  }
  
  func testMarking() {
    
    let marking1 = Marking<P>([.p1: ["1", "2"], .p2: ["3"], .p3: ["4","5"]])
    let marking2 = Marking<P>([.p1: ["6", "7"], .p2: ["8"], .p3: ["9","10"]])
    let marking3 = Marking<P>([.p1: ["1"], .p2: [], .p3: ["4"]])
    let marking4 = Marking<P>([.p1: ["1", "1"], .p2: [], .p3: ["4","4"]])

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
  }

  static var allTests = [
      ("testExample", testExample),
  ]
}
