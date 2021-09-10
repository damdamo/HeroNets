import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsBindingsTests: XCTestCase {
  
  typealias Label = String
  typealias KeyMFDD = Key<String>
  typealias ValueMFDD = String
  
  enum P: Place, Equatable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  // Transform mfdd into a set of dictionnaries with all possibilities
  func simplifyBinding(bindings: MFDD<KeyMFDD,ValueMFDD>) -> Set<[String:String]> {
    
    var bindingSimplify: Set<[String: String]> = []
    var dicTemp: [String: String] = [:]
    
    for el in bindings {
      for (k,v) in el {
        dicTemp[k.label] = v
      }
      bindingSimplify.insert(dicTemp)
      dicTemp = [:]
    }
    
    return bindingSimplify
  }
  
  func testBinding0() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

//    let conditionList: [Pair<String>]? = nil

    let conditionList: [Pair<String>] = [Pair("$y","1"), Pair("$x", "$z")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$x", "$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2"], .p2: ["1", "1", "2"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)

    // Cas bug: [$y, $z, $x]
    print(mfdd)
    print(mfdd.count)
   }

  func testBinding01() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

//    let conditionList: [Pair<String>]? = nil

//    let conditionList: [Pair<String>] = [Pair("$y","1"), Pair("$x", "$z")]
    let conditionList: [Pair<String>] = [Pair("$x","1")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
//      .pre(from: .p2, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p3, labeled: ["$x"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2", "4"], .p2: ["1", "2", "3"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    


    print(mfdd)
    print("END")
   }
  
  
  func testBinding1() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Pair<String>] = [Pair("$x","1"), Pair("$y", "$z")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
    let marking1 = Marking<P>([.p1: ["1","1","2","3"], .p2: ["1", "2", "3"], .p3: []])

    let bindings = model.fireableBindings(for: .t1, with: marking1, factory: factory)
      
    let bindingSimplified = simplifyBinding(bindings: bindings)
    let expectedRes: Set<[String:String]> = [["$x": "1", "$z": "2", "$y": "2"], ["$z": "1", "$x": "1", "$y": "1"], ["$y": "3", "$z": "3", "$x": "1"]]
    

    print("---------------")
    print(bindings)
    print("---------------")
    XCTAssertEqual(bindingSimplified, expectedRes)

  }

  func testBinding2() {

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

    func eq(_ n1: Int, _ n2: Int) -> Bool ::
    // Equality between two numbers
      if n1 = n2
        then true
        else false
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionListCurry: [Pair<String>] = [Pair("$f","div")]
    let conditionListApply: [Pair<String>] = [Pair("eq($y,0)","false")]

    let model = HeroNet<P2, T2>(
      .pre(from: .op, to: .curry, labeled: ["$f"]),
      .pre(from: .p1, to: .curry, labeled: ["$x"]),
      .pre(from: .p1, to: .apply, labeled: ["$y"]),
      .pre(from: .p2, to: .apply, labeled: ["$g"]),
      .post(from: .curry, to: .p2, labeled: ["$f($x)"]),
      .post(from: .apply, to: .res, labeled: ["$g($y)"]),
      guards: [.curry: conditionListCurry, .apply: conditionListApply],
      interpreter: interpreter
    )

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
    let marking1 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["1", "1", "2"], .p2: [], .res: []])
    let marking2 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["0", "1"], .p2: ["div(2)"], .res: []])

    let bindings1: MFDD<KeyMFDD,ValueMFDD> = model.fireableBindings(for: .curry, with: marking1, factory: factory)
    let bindings2: MFDD<KeyMFDD,ValueMFDD> = model.fireableBindings(for: .apply, with: marking2, factory: factory)
    
    print(bindings1)
    print("-------------------------------")
    print(bindings2)
    
    XCTAssertEqual(simplifyBinding(bindings: bindings1), Set([["$f": "div", "$x": "1"], ["$f": "div", "$x": "2"]]))
    XCTAssertEqual(simplifyBinding(bindings: bindings2), Set([["$y": "1", "$g": "div(2)"]]))
  }
  
  func testBinding3() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Pair<String>]? = nil

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$x","$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "2"], .p2: ["1", "2"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    XCTAssertEqual(simplifyBinding(bindings: mfdd), Set([["$x": "1", "$y": "2", "$z": "2"], ["$x": "2", "$y": "1", "$z": "1"]]))
  }
  
  
//  static var allTests = [
//    ("testBinding1", testBinding1),
//    ("testBinding2", testBinding2),
//  ]
}

