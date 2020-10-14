import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsPerformancesTests: XCTestCase {
  
  func testPerformance1() {
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
    
    let conditionList: [Condition]? = [Condition("$f","add")]
    
    let model = HeroNet<P1, T1>(
      .pre(from: .op, to: .apply, labeled: ["f"]),
      .pre(from: .n, to: .apply, labeled: ["x","y"]),
      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
      .post(from: .apply, to: .op, labeled: ["$f"]),
      guards: [.apply: conditionList],
      interpreter: interpreter
    )
    
    let len = 1000
    
    var seq: Multiset<String>  = []
    for i in 0...len {
      seq.insert(String(i))
    }
        
    let factory = MFDDFactory<String,String>()
    let marking1 = Marking<P1>([.op: ["add","sub","mul","div"], .n: seq, .res: []])
    
    let s: Stopwatch = Stopwatch()
    
    let x = model.fireableBindings(for: .apply, with: marking1, factory: factory)!
    print(x.count)
    
    print("----------------------------------")
    print(s.elapsed.humanFormat)
    print("----------------------------------")
  }
  
  static var allTests = [
    ("testPerformance1", testPerformance1),
  ]
}

