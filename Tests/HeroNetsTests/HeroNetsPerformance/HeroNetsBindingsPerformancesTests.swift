//import Interpreter
//import DDKit
//@testable import HeroNets
//import XCTest
//
//final class HeroNetsPerformancesTests: XCTestCase {
//
//  typealias Label = String
//  typealias ValueMFDD = String
//
//  // ------------------------- HELPER ------------------------- //
//
//  func testBindingNet<Place, Transition>(
//    nbTry: Int,
//    marking: Marking<Place>,
//    transition: Transition,
//    heroNet: HeroNet<Place, Transition>,
//    factory: MFDDFactory<KeyMFDD<String>, String>
//  )
//  -> (avgTime: Double, stdTime: Double, stateNumber: Int) {
//
//    var times: [Double] = []
//    var s: Stopwatch = Stopwatch()
//    var count = 0
//
//    for i in 0 ..< nbTry {
//      print("Try nb: \(i)")
//      s.reset()
//      let x = heroNet.fireableBindings(for: transition, with: marking, factory: factory)
//      times.append(s.elapsed.s)
//      print(s.elapsed.humanFormat)
//      s.reset()
//      count = x.count
//    }
//    let average = times.reduce(0, +) / Double(times.count)
//    let standard_deviation: Double = times
//      .map({(x: Double) -> Double in return (x - average)*(x - average)})
//      .reduce(0, +)
//      .squareRoot()
//
//    return (
//      avgTime: average.truncate(places: 4),
//      stdTime: standard_deviation.truncate(places: 4),
//      stateNumber: count
//    )
//
//  }
//
//  func pprintBinding(info: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)]) {
//    print("----------------------------------")
//    for (key,value) in info.sorted(by: {$0.key < $1.key}) {
//      print("Nb P1: \(key) / Temps: \(value.avgTime) s / Nombre d'état: \(value.stateNumber) / Ecart-type: \(value.stdTime)")
//    }
//    print("----------------------------------")
//  }
//  
//  func computeCSSHeroNetsMFDD<Place: Comparable, Transition>(
//    nbTry: Int,
//    marking: Marking<Place>,
//    heroNet: HeroNet<Place, Transition>,
//    factory: MFDDFactory<Place, Pair<Place.Content.Key, Int>> //<KeyMFDD<String>, String>
//  )
//  -> (avgTime: Double, stdTime: Double, stateNumber: Int) {
//    
//    var times: [Double] = []
//    var s: Stopwatch = Stopwatch()
//    var count = 0
//    let lol = Baseline(heroNet: heroNet)
//    
//    for i in 0 ..< nbTry {
//      print("Try nb: \(i)")
//      s.reset()
////      let x = heroNet.computeStateSpace(from: marking, markingMFDDFactory: factory)
//      let x = heroNet.computeStateSpaceAlternative(from: marking)
////      let x = lol.CSSBruteForceWithOptimizedNet(marking: marking)
//      times.append(s.elapsed.s)
//      print(s.elapsed.humanFormat)
//      s.reset()
//      count = x.count
//    }
//    let average = times.reduce(0, +) / Double(times.count)
//    let standard_deviation: Double = times
//      .map({(x: Double) -> Double in return (x - average)*(x - average)})
//      .reduce(0, +)
//      .squareRoot()
//    
//    return (
//      avgTime: average.truncate(places: 4),
//      stdTime: standard_deviation.truncate(places: 4),
//      stateNumber: count
//    )
//    
//  }
//
//
//  // ------------------------- END HELPER ------------------------- //
//
//  let module: String = """
//  func add(_ x: Int, _ y: Int) -> Int ::
//    x + y
//  func sub(_ x: Int, _ y: Int) -> Int ::
//    x - y
//  func mul(_ x: Int, _ y: Int) -> Int ::
//    x * y
//  func div(_ x: Int, _ y: Int) -> Int ::
//    x / y
//  func mod(_ x: Int, _ y: Int) -> Int ::
//    if y = 0
//    then 0
//    else
//      if x < y
//      then x
//      else
//        if x > y
//        then mod(x-y,y)
//        else 0
//  func eq(_ n1: Int, _ n2: Int) -> Bool ::
//  // Equality between two numbers
//    if n1 = n2
//      then true
//      else false
//  """
//
//  // ------------------------- TEST 1 ------------------------- //
//
//  func testPerformance1() {
//    enum P1: Place, Comparable {
//      typealias Content = Multiset<String>
//      case p1, p2
//    }
//    enum T1: Transition {
//      case apply
//    }
//
//    // Try number
//    let nbTry = 1
//    // Element numbers to construct the marking
//    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nbElInPlace = [5]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = nil
//    let model = HeroNet<P1, T1>(
//      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$f"]),
////      .post(from: .apply, to: .res, labeled: ["$x + $y"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
////    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    let factory = MFDDFactory<P1, Pair<P1.Content.Key, Int>>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P1>
//
//    for len in nbElInPlace {
//      for i in 0 ..< len {
//        for _ in 0 ..< 2 {
//          seq.insert(String(i))
//        }
//      }
//      print(seq)
//      marking = Marking<P1>([.p1: seq, .p2: seq])
//      print("Nb P1: \(len)")
////      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T1.apply, heroNet: model, factory: factory)
//      res[len] = computeCSSHeroNetsMFDD(nbTry: nbTry, marking: marking, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//  // ------------------------- TEST 2 ------------------------- //
//
//  func testPerformanceSameVariable() {
//    enum P1: Place {
//      typealias Content = Multiset<String>
//      case p1, p2, res
//    }
//    enum T1: Transition {
//      case apply
//    }
//
//    // Try number
//    let nbTry = 5
//    // Element numbers to construct the marking
//    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nbElInPlace = [100,200,300]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = nil
//    let model = HeroNet<P1, T1>(
//      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$x"]),
//      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
//    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P1>
//
//    for len in nbElInPlace {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      marking = Marking<P1>([.p1: seq, .p2: ["add","sub","mul","div"], .res: []])
//      print("Nb P1: \(len)")
//      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T1.apply, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//  // ------------------------- TEST 3 ------------------------- //
//
//  func testPerformanceConstantCondition() {
//    enum P1: Place {
//      typealias Content = Multiset<String>
//      case p1, p2, res
//    }
//    enum T1: Transition {
//      case apply
//    }
//
//    // Try number
//    let nbTry = 5
//    // Element numbers to construct the marking
//    // [100,500,1000,2000]
//    let nbElInPlace = [100,200,300]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = [Pair("$x","2")]
//    let model = HeroNet<P1, T1>(
//      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$f"]),
//      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
//    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P1>
//
//    for len in nbElInPlace {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      marking = Marking<P1>([.p1: seq, .p2: ["add","sub","mul","div"], .res: []])
//      print("Nb P1: \(len)")
//      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T1.apply, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//  // ------------------------- TEST 4 ------------------------- //
//  func testPerformanceOneCondition() {
//    enum P1: Place {
//      typealias Content = Multiset<String>
//      case p1, p2, res
//    }
//    enum T1: Transition {
//      case apply
//    }
//
//    // Try number
//    let nbTry = 5
//    // Element numbers to construct the marking
//    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nbElInPlace = [100,200,300]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = [Pair("$x","$y+1")]
//    let model = HeroNet<P1, T1>(
//      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
//      .pre(from: .p2, to: .apply, labeled: ["$f"]),
//      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
//    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P1>
//
//    for len in nbElInPlace {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      marking = Marking<P1>([.p1: seq, .p2: ["add","sub","mul","div"], .res: []])
//      print("Nb P1: \(len)")
//      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T1.apply, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//  // ------------------------- TEST 5 ------------------------- //
//
//  func testPerformanceFull0() {
//    enum P1: Place {
//      typealias Content = Multiset<String>
//      case op, n, res
//    }
//
//    enum T1: Transition {
//      case apply
//    }
//
//    // Try number
//    let nbTry = 3
//    // Element numbers to construct the marking
//    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nbElInPlace = [40]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = [Pair("add($a,5)","6"), Pair("eq($c,0)", "false"),Pair("mod($g($b,$c),2)", "0")]
//    let model = HeroNet<P1, T1>(
//      .pre(from: .op, to: .apply, labeled: ["$f","$g"]),
//      .pre(from: .n, to: .apply, labeled: ["$a","$b", "$c", "$d"]),
//      .post(from: .apply, to: .res, labeled: ["$f($a,$b)"]),
//      .post(from: .apply, to: .op, labeled: ["$f", "$g"]),
//      guards: [.apply: conditionList],
//      interpreter: interpreter
//    )
//    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P1>
//
//    for len in nbElInPlace {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      marking = Marking<P1>([.op: ["add","sub","mul","div"], .n: seq, .res: []])
//      print("Nb P1: \(len)")
//      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T1.apply, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//  // ------------------------- TEST 6 ------------------------- //
//
//  func testPerformanceFull1() {
//    enum P: Place, Hashable, Comparable {
//      typealias Content = Multiset<String>
//
//      case p1,p2,p3,res
//    }
//
//    enum T: Transition {
//      case t1
//    }
//
//    // Try number
//    let nbTry = 1
//    // Element numbers to construct the marking
//    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
//    let nbElInPlace = [10]
//
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    let conditionList: [Pair<String, String>]? = [Pair("$x","$y-1"), Pair("$y", "$z"), Pair("$a", "1")]
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z", "$a"]),
//      .pre(from: .p3, to: .t1, labeled: ["$b", "1"]),
//      .post(from: .t1, to: .res, labeled: ["$x"]),
//      guards: [.t1: conditionList],
//      interpreter: interpreter
//    )
//    let factory = MFDDFactory<KeyMFDD<Label>,ValueMFDD>()
//    // How many values in the place
//    var res: [Int: (avgTime: Double, stdTime: Double, stateNumber: Int)] = [:]
//    var seq: Multiset<String>  = []
//    var marking: Marking<P>
//
//    for len in nbElInPlace {
//      for i in 0..<len {
//        seq.insert(String(i))
//      }
//      marking = Marking<P>([.p1: seq, .p2: seq, .p3: seq, .res: []])
//
//      print("Nb P1: \(len)")
//      res[len] = testBindingNet(nbTry: nbTry, marking: marking, transition: T.t1, heroNet: model, factory: factory)
//      seq = []
//    }
//
//    pprintBinding(info: res)
//  }
//
//
////  static var allTests = [
////    ("testPerformance1", testPerformance1),
////  ]
//}
//
