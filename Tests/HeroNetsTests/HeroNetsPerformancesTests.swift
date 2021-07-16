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
    func mod(_ x: Int, _ y: Int) -> Int ::
      if y = 0
      then 0
      else
        if x < y
        then x
        else
          if x > y
          then mod(x-y,y)
          else 0
    func eq(_ n1: Int, _ n2: Int) -> Bool ::
    // Equality between two numbers
      if n1 = n2
        then true
        else false
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    // print(try! interpreter.eval(string: "eq(mod(25,5),0)"))
    
    let conditionList: [Pair<String>]? = [Pair("eq(mod($a,2),0)","true")]
//    let conditionList: [Pair<String>]? = [Pair("add($a,5)","10"), Pair("eq($c,0)", "false"), Pair("mod($g($b,$c),2)", "0")]

    let model = HeroNet<P1, T1>(
      .pre(from: .op, to: .apply, labeled: ["$f","$g"]),
      .pre(from: .n, to: .apply, labeled: ["$a","$b", "$c", "$d"]),
      .post(from: .apply, to: .res, labeled: ["$f($a,$b)"]),
      .post(from: .apply, to: .op, labeled: ["$f", "$g"]),
      guards: [.apply: conditionList],
      interpreter: interpreter
    )

    let len = 10

    var seq: Multiset<String>  = []
    for i in 0...len {
      seq.insert(String(i))
    }

    let factory = MFDDFactory<String,String>()
    let marking1 = Marking<P1>([.op: ["add","sub","mul","div"], .n: seq, .res: []])


    let s: Stopwatch = Stopwatch()

//    let x = model.fireableBindings(for: .apply, with: marking1, factory: factory)!
//    print(x.count)
//    print(x)

    print("----------------------------------")
    print(s.elapsed.humanFormat)
    print("----------------------------------")
//
//    s.reset()
//
//    let l = model.fireableBindingsNaive(for: .apply, with: marking1)
//    print(l.count)
//
//    print("----------------------------------")
//    print(s.elapsed.humanFormat)
//    print("----------------------------------")

  }
  
  static var allTests = [
    ("testPerformance1", testPerformance1),
  ]
}

