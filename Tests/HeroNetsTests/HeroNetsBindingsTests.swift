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
  
  func testBinding() {
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Condition] = [Condition("$x","1"), Condition("$x", "$y-1")]
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )
    //   func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD,ValueMFDD>.Pointer? {

    let factory = MFDDFactory<String,String>()
    let marking1 = Marking<P>([.p1: ["1","1","2","5"], .p2: ["1", "2"], .p3: []])
    
    let bindings1: MFDD<String, String> = model.fireableBindings(for: .t1, with: marking1, factory: factory)!
        
    XCTAssertEqual(Set(bindings1.map({model.clearDicVar($0)})), Set([["x": "1", "z": "1", "y": "2"], ["z": "2", "x": "1", "y": "2"]]))

  }
  
  func testSortKeys() {
    
    let interpreter = Interpreter()
    
    let conditionList1: [Condition] = [Condition("$x", "$z"), Condition("$x", "$x"), Condition("$x", "1"), Condition("$x", "$y"), Condition("$y", "1"), Condition("$z", "5"), Condition("$z", "$z + 2"), Condition("$z", "$z + 2")]
    
    let model1 = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList1, .t2: nil],
      interpreter: interpreter
    )
    
    XCTAssertEqual(model1.countUniqueVarInConditions(for: .t1), ["x": 2, "y": 1, "z": 3])
    
    let conditionList2: [Condition] = []
    
    let model2 = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList2, .t2: nil],
      interpreter: interpreter
    )
    
    XCTAssertEqual(model2.countUniqueVarInConditions(for: .t1), ["x": 0, "y": 0, "z": 0])
    
    let conditionList3: [Condition] = [Condition("$x", "$z"), Condition("$x", "$x"), Condition("$x", "1"), Condition("$x", "$y"), Condition("$z", "5"), Condition("$z", "$z + 2"), Condition("$z", "$z + 2")]
    
    let model3 = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList3, .t2: nil],
      interpreter: interpreter
    )
    
    XCTAssertEqual(model3.countUniqueVarInConditions(for: .t1), ["x": 2, "y": 0, "z": 3])
    
  }
  
  static var allTests = [
    ("testBinding", testBinding),
    ("testSortKeys", testSortKeys),
  ]
}

