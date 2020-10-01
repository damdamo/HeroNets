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
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p2, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: [Condition("$x","$z")], .t2: nil],
      interpreter: interpreter
    )
    //   func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD,ValueMFDD>.Pointer? {

    let factory = MFDDFactory<String,String>()
    
    print(model.fireableBindings(factory: factory, vars: ["x", "y"], values: ["a", "b", "c"]))
  }
  
  static var allTests = [
    ("testBinding", testBinding),
  ]
}

