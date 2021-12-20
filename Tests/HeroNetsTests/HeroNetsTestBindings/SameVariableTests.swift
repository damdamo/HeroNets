import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class SameVariableTests: XCTestCase {
  
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
  
  func testWithSameVariableSameArc() {
    let factory = MFDDFactory<KeyMFDDVar, ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Guard]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, x]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["3", "3", "5", "42"], .p2: ["1", "2", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "3", "$z": "1"], ["$x": "3", "$z": "2"], ["$x": "3", "$z": "100"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithSameVariableDifferentArcs0() {
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Guard]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, z]),
      .pre(from: .p2, to: .t1, labeled: [x]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "5", "42"], .p2: ["1", "2", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "2", "$z": "5"], ["$x": "1", "$z": "42"], ["$z": "5", "$x": "1"], ["$z": "1", "$x": "2"], ["$x": "2", "$z": "42"], ["$x": "1", "$z": "2"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithSameVariableDifferentArcs1() {
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Guard]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, z]),
      .pre(from: .p2, to: .t1, labeled: [x]),
      .post(from: .t1, to: .p3, labeled: [z]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "1", "2"], .p2: ["1", "3"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "1", "$z": "1"], ["$x": "1", "$z": "2"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithSameVariableInAllArcs() {
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let module = ""
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Guard]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [x]),
      .pre(from: .p3, to: .t1, labeled: [x]),
      guards: [.t1: conditionList],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "4", "5"], .p3: ["1", "2", "4"]])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$y": "3", "$x": "2"], ["$x": "1", "$y": "3"], ["$x": "2", "$y": "1"], ["$y": "2", "$x": "1"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
}

