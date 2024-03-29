import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class GuardTests: XCTestCase {
  
  let a = ILang.var("$a")
  let b = ILang.var("$b")
  let x = ILang.var("$x")
  let y = ILang.var("$y")
  let z = ILang.var("$z")
  
  typealias Var = String
  typealias KeyMFDDVar = KeyMFDD<Var>
  typealias ValueMFDD = Val
  typealias Guard = Pair<ILang, ILang>
  
  enum P: Place, Equatable {
    typealias Content = Multiset<Val>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1
  }
  
  // Transform mfdd into a set of dictionnaries with all possibilities
  func simplifyBinding(bindings: MFDD<KeyMFDDVar,ValueMFDD>) -> Set<[String:String]> {

    var bindingSimplify: Set<[String: String]> = []
    var dicTemp: [String: String] = [:]

    for el in bindings {
      for (k,v) in el {
        dicTemp[k.label] = v.description
      }
      bindingSimplify.insert(dicTemp)
      dicTemp = [:]
    }

    return bindingSimplify
  }
  
  func testNoBinding() {
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard]? = nil
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let lol: Val = "btk"
    print(type(of: lol))
    print(lol)
    
    let marking = Marking<P>([.p1: [], .p2: [], .p3: []])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = []
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithoutGuard0() {

    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard]? = nil

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "2"], .p2: ["4", "5"], .p3: []])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "1", "$y": "2", "$z": "4"], ["$x": "2", "$y": "1", "$z": "4"], ["$x": "1", "$y": "2", "$z": "5"], ["$x": "2", "$y": "1", "$z": "5"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  func testWithoutGuard1() {

    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard]? = nil

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x]),
      .pre(from: .p2, to: .t1, labeled: [y]),
      .post(from: .t1, to: .p3, labeled: [x]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "2"], .p2: [], .p3: []])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = []
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  func testWithGuardSimple0() {

    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard] = [Pair(x, .exp("$z+1")), Pair(y, .exp("$z-1"))]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["2", "3"], .p3: []])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "3", "$y": "1", "$z": "2"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  func testWithGuardSimple1() {

    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair(x, .exp("$a+1")), Pair(.exp("$a+1"),y), Pair(b, .exp("$y+1"))]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [a]),
      .pre(from: .p3, to: .t1, labeled: [b]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "2", "2", "3", "4"], .p2: ["1", "2", "3", "4"], .p3: ["1", "2", "3", "4"]])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "2", "$y": "2", "$a": "1", "$b": "3"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  func testConstantPropagation() {

    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard] = [Pair(z, .val("2")), Pair(y, .val("1"))]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    var marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["2", "3"], .p3: []])
    var mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    var expectedRes: Set<[String:String]> = [["$x": "2"], ["$x": "3"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)

    print("------------------------------")

    marking = Marking<P>([.p1: ["1", "1", "2", "3"], .p2: ["2", "3"], .p3: []])
    mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    expectedRes = [["$x": "1"], ["$x": "2"], ["$x": "3"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  // Test for guards of the form (x,y) where x and y are not on the same arc
  func testOptimisationGuard0() {

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair(x,z)]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "1", "2", "42"], .p2: ["1", "2", "3"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$y": "1", "$z": "1"], ["$y": "2", "$z": "1"], ["$y": "42", "$z": "1"], ["$y": "1", "$z": "2"], ["$y": "42", "$z": "2"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  // Test for guards of the form (x,y), where x and y are on the same arc
  func testOptimisationGuard1() {

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair(x,y)]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "1", "2", "42"], .p2: ["1", "2", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$y": "1", "$z": "1"], ["$y": "1", "$z": "2"], ["$y": "1", "$z": "100"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  // Test for guards with many variables that are just the same
  func testOptimisationGuard2() {
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair(x,y), Pair(x,z), Pair(y,z)]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [y]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "1", "2", "42"], .p2: ["1", "2", "3", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$z": "1"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  // Test for guards with conditions that have the same variable
  func testOptimisationGuard3() {
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard] = [Pair(.exp("$x%2"), .val("0")), Pair(.exp("$z%2"),.val("1"))]
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [y]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )

    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["4", "5", "6"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "2", "$z": "5", "$y": "1"], ["$x": "2", "$z": "5", "$y": "3"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
}

