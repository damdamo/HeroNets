import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsBindingsTests: XCTestCase {
  
  enum P: Place, Equatable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
//  func testBinding1() {
//
//    let module: String = """
//    func add(_ x: Int, _ y: Int) -> Int ::
//      x + y
//    """
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//
//    let conditionList: [Pair<String>] = [Pair("$x","1"), Pair("$x", "$y")]
//
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z"]),
//      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
//      guards: [.t1: conditionList, .t2: nil],
//      interpreter: interpreter
//    )
//
//    let marking1 = Marking<P>([.p1: ["1","1","2","5"], .p2: ["1", "2"], .p3: []])
//
//    let factory = MFDDFactory<Key, String>()
//
//    print(model.fireableBindings(for: .t1, with: marking1, factory: factory))
//
//
//   }
  
  func testBinding1() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Pair<String>] = [Pair("$x","1"), Pair("$x", "$y")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let factory = MFDDFactory<Key,String>()
    let marking1 = Marking<P>([.p1: ["1","1","2","5"], .p2: ["1", "2"], .p3: []])

    let bindings1 = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    var s: Set<[String: String]> = []
    var dic: [String: String] = [:]
    
    for el in bindings1 {
      for (k,v) in el {
        dic[k.name] = v
      }
      s.insert(dic)
      dic = [:]
    }
        
    XCTAssertEqual(s, Set([["$z": "2", "$x": "1", "$y": "1"], ["$y": "1", "$z": "1", "$x": "1"]]))

//    XCTAssertEqual(Set(bindings1.map({model.clearDicVar($0)})), Set([["$z": "2", "$x": "1", "$y": "1"], ["$y": "1", "$z": "1", "$x": "1"]]))

  }

//  func testBinding2() {
//
//    enum P2: Place {
//      typealias Content = Multiset<String>
//      case op, p1, p2, res
//    }
//
//    enum T2: Transition {
//      case curry, apply
//    }
//
//    let module: String = """
//    func add(_ x: Int) -> (Int) -> Int ::
//      func foo(_ y: Int) -> Int ::
//        x + y
//
//    func sub(_ x: Int) -> (Int) -> Int ::
//      func foo(_ y: Int) -> Int ::
//        x - y
//
//    func mul(_ x: Int) -> (Int) -> Int ::
//      func foo(_ y: Int) -> Int ::
//        x * y
//
//    func div(_ x: Int) -> (Int) -> Int ::
//      func foo(_ y: Int) -> Int ::
//        x / y
//
//    func eq(_ n1: Int, _ n2: Int) -> Bool ::
//    // Equality between two numbers
//      if n1 = n2
//        then true
//        else false
//    """
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//
//    let conditionListCurry: [Condition] = [Condition("$f","div")]
//    let conditionListApply: [Condition] = [Condition("eq($y,0)","false")]
//
//    let model = HeroNet<P2, T2>(
//      .pre(from: .op, to: .curry, labeled: ["$f"]),
//      .pre(from: .p1, to: .curry, labeled: ["$x"]),
//      .pre(from: .p1, to: .apply, labeled: ["$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$g"]),
//      .post(from: .curry, to: .p2, labeled: ["$f($x)"]),
//      .post(from: .apply, to: .res, labeled: ["$g($y)"]),
//      guards: [.curry: conditionListCurry, .apply: conditionListApply],
//      interpreter: interpreter
//    )
//
//    let factory = MFDDFactory<String,String>()
//    let marking1 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["1", "1", "2"], .p2: [], .res: []])
//    let marking2 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["0", "1"], .p2: ["div(2)"], .res: []])
//
//    let bindings1: MFDD<String, String> = model.fireableBindings(for: .curry, with: marking1, factory: factory)!
//    let bindings2: MFDD<String, String> = model.fireableBindings(for: .apply, with: marking2, factory: factory)!
//
//    XCTAssertEqual(Set(bindings1.map({model.clearDicVar($0)})), Set([["$f": "div", "$x": "1"], ["$f": "div", "$x": "2"]]))
//    XCTAssertEqual(Set(bindings2.map({model.clearDicVar($0)})), Set([["$y": "1", "$g": "div(2)"]]))
//
//  }
  
//  func testSortKeys() {
//
//    let interpreter = Interpreter()
//
//    let conditionList1: [Condition] = [Condition("$x", "$z"), Condition("$x", "$x"), Condition("$x", "1"), Condition("$x", "$y"), Condition("$y", "1"), Condition("$z", "5"), Condition("$z", "$z + 2"), Condition("$z", "$z + 2")]
//
//    let model1 = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z"]),
//      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
//      guards: [.t1: conditionList1, .t2: nil],
//      interpreter: interpreter
//    )
//
//    XCTAssertEqual(model1.countUniqueVarInConditions(for: .t1), ["$x": 2, "$y": 1, "$z": 3])
//
//    let conditionList2: [Condition] = []
//
//    let model2 = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z"]),
//      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
//      guards: [.t1: conditionList2, .t2: nil],
//      interpreter: interpreter
//    )
//
//    XCTAssertEqual(model2.countUniqueVarInConditions(for: .t1), ["$x": 0, "$y": 0, "$z": 0])
//
//    let conditionList3: [Condition] = [Condition("$x", "$z"), Condition("$x", "$x"), Condition("$x", "1"), Condition("$x", "$y"), Condition("$z", "5"), Condition("$z", "$z + 2"), Condition("$z", "$z + 2")]
//
//    let model3 = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z"]),
//      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
//      guards: [.t1: conditionList3, .t2: nil],
//      interpreter: interpreter
//    )
//
//    XCTAssertEqual(model3.countUniqueVarInConditions(for: .t1), ["$x": 2, "$y": 0, "$z": 3])
//
//  }
  
  static var allTests = [
    ("testBinding1", testBinding1),
//    ("testBinding2", testBinding2),
//    ("testSortKeys", testSortKeys),
  ]
}

