import XCTest
@testable import HeroNets
import Interpreter

final class AllFiringTests: XCTestCase {
  
  func testIsFireable() {
    
    enum P: Place {
      typealias Content = Multiset<String>
      
      case p1,p2,p3,p4
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
      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p3, labeled: ["$x"]),
      .post(from: .t1, to: .p4, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["1","2"], .p2: ["1", "2"], .p3: [], .p4: []])
    
    var expectedRes: Set<Marking<P>> = []
    expectedRes.insert([.p1: ["1","2"], .p2: ["1", "2"], .p3: [], .p4: []])
    expectedRes.insert([.p1: [], .p2: ["1"], .p3: ["2"], .p4: ["3"]])
    expectedRes.insert([.p1: [], .p2: ["2"], .p3: ["1"], .p4: ["3"]])
    
    XCTAssertEqual(model.generateAllFiring(for: .t1, with: marking1), expectedRes)
  }
  
  
  static var allTests = [
    ("testIsFireable", testIsFireable),
  ]
}
