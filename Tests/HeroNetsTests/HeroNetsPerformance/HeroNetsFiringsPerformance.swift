//import Interpreter
//import DDKit
//@testable import HeroNets
//import XCTest
//
//final class HeroNetsFiringsTests: XCTestCase {
//
//  typealias Label = String
//  typealias KeyMFDD = Key<String>
//  typealias ValueMFDD = String
//
//  func testPerformance1() {
//    enum P1: Place {
//      typealias Content = Multiset<String>
//      case p1, p2, res
//    }
//
//    enum T1: Transition {
//      case apply
//    }
//
//    let module: String = """
//    func add(_ x: Int, _ y: Int) -> Int ::
//      x + y
//    func sub(_ x: Int, _ y: Int) -> Int ::
//      x - y
//    func mul(_ x: Int, _ y: Int) -> Int ::
//      x * y
//    func div(_ x: Int, _ y: Int) -> Int ::
//      x / y
//    func mod(_ x: Int, _ y: Int) -> Int ::
//      if y = 0
//      then 0
//      else
//        if x < y
//        then x
//        else
//          if x > y
//          then mod(x-y,y)
//          else 0
//    func eq(_ n1: Int, _ n2: Int) -> Bool ::
//    // Equality between two numbers
//      if n1 = n2
//        then true
//        else false
//    """
//
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//
//    let conditionList: [Pair<String>]? = nil
//
//    let model = HeroNet<P1, T1>(
//      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$f"]),
////      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
//      .post(from: .apply, to: .res, labeled: ["$x"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
//
//    // Number of tests
//    let test_number = 1
//
//    // How many values in the place
////    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nb_el_in_place = [200]
//    var res: [Int: (avg_time: Double, count: Int, std_time: Double)] = [:]
//
//    var seq: Multiset<String>  = []
//
//
//    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()
//
//    var times: [Double] = []
//    var s: Stopwatch = Stopwatch()
//    var count = 0
//
//    for len in nb_el_in_place {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      let marking1 = Marking<P1>([.p1: seq, .p2: ["add","sub","mul"], .res: []])
//      print("Nb P1: \(len)")
//      for i in 0 ..< test_number {
//        print("Try nb: \(i)")
//        s.reset()
//        let x = model.generateAllFiring(for: .apply, with: marking1)
//        print(x.count)
//        times.append(s.elapsed.s)
//        s.reset()
//        count = x.count
//      }
//      let average = times.reduce(0, +) / Double(times.count)
//      let standard_deviation: Double = times
//        .map({(x: Double) -> Double in return (x - average)*(x - average)})
//        .reduce(0, +)
//        .squareRoot()
//      res[len] = (average.truncate(places: 4), count, standard_deviation.truncate(places: 4))
//      seq = []
//      times = []
//
//    }
//
//    print("----------------------------------")
//    for (key,value) in res.sorted(by: {$0.key < $1.key}) {
//      print("Nb P1: \(key) / Temps: \(value.avg_time) s / Nombre d'état: \(value.count) / Ecart-type: \(value.std_time)")
//    }
//    print("----------------------------------")
//  }
//
//  
//
////  static var allTests = [
////    ("testPerformance1", testPerformance1),
////  ]
//}
//
