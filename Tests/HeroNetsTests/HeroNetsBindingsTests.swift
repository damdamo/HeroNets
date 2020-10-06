import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsBindingsTests: XCTestCase {
  
  func testBinding() {
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
    
    let conditionList: [Condition] = [Condition("$x", "$z"), Condition("$x", "$x"), Condition("$x", "1"), Condition("$x", "$y"), Condition("$y", "1"), Condition("$z", "5"), Condition("$z", "$z + 2"), Condition("$z", "$z + 2")]
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )
    //   func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD,ValueMFDD>.Pointer? {

    let factory = MFDDFactory<String,String>()
    let morphismFactory = MFDDMorphismFactory<String,String>(nodeFactory: factory)
    let marking1 = Marking<P>([.p1: ["1","2","5"], .p2: ["3", "4"], .p3: []])
    
    var x: MFDD<String, String> = model.fireableBindings(for: .t1, with: marking1, factory: factory)!
    
//    print(x.factory.morphisms.filter(excluding: ["x": ["3"]]))
//    print(x.factory.morphisms.insert(assignments: ["p1_x": "42"]))
//    morphismFactory.filter(excluding: ["x": ["3"]])
//    print(x.factory.morphisms.union(x, x))
//    x.filter(excluding: ["x":"3"])
//    print(x.count)
//    print(x)
//    let morphism = factory.morphisms.filter(excluding: [(key: "p1_x", values: ["2"])])
//    x = morphism.apply(on: x)
//    print(x.count)
    
    model.orderPlacesKeys(for: .t1)

  }
  
  static var allTests = [
    ("testBinding", testBinding),
  ]
}

