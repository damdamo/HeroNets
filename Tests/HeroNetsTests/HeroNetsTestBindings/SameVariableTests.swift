import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class SameVariableTests: XCTestCase {
  
  typealias Label = String
  typealias KeyMFDD = Key<String>
  typealias ValueMFDD = String
  
  enum P: Place, Equatable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1
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
  
  func testWithSameVariableSameArc() {
    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
    let module = ""
    let conditionList: [Pair<String>]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$x"]),
      .pre(from: .p2, to: .t1, labeled: ["$z"]),
      .post(from: .t1, to: .p3, labeled: ["$z"]),
      guards: [.t1: conditionList],
      module: module
    )
    
    let marking = Marking<P>([.p1: ["3", "3", "5", "42"], .p2: ["1", "2", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "3", "$z": "1"], ["$x": "3", "$z": "2"], ["$x": "3", "$z": "100"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithSameVariableDifferentArcs() {
    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
    let module = ""
    let conditionList: [Pair<String>]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$z"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p3, labeled: ["$z"]),
      guards: [.t1: conditionList],
      module: module
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "5", "42"], .p2: ["1", "2", "100"], .p3: []])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$x": "2", "$z": "5"], ["$x": "1", "$z": "42"], ["$z": "5", "$x": "1"], ["$z": "1", "$x": "2"], ["$x": "2", "$z": "42"], ["$x": "1", "$z": "2"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
  func testWithSameVariableInAllArcs() {
    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
    let module = ""
    let conditionList: [Pair<String>]? = nil
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .pre(from: .p3, to: .t1, labeled: ["$x"]),
      guards: [.t1: conditionList],
      module: module
    )
    
    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "4", "5"], .p3: ["1", "2", "4"]])
    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
    let expectedRes: Set<[String:String]> = [["$y": "3", "$x": "2"], ["$x": "1", "$y": "3"], ["$x": "2", "$y": "1"], ["$y": "2", "$x": "1"]]
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }
  
}

