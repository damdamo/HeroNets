import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsPerformancesTests: XCTestCase {

  
  func testPerformance1() {
    enum P1: Place {
      typealias Content = Multiset<String>
      case p1, p2, res
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
    
    let conditionList: [Pair<String>]? = nil

    let model = HeroNet<P1, T1>(
      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .apply, labeled: ["$f"]),
      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
      guards: [.apply: conditionList],
      interpreter: interpreter
    )

    // Number of tests
    let test_number = 5
        
    // How many values in the place
    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
    let nb_el_in_place = [2]
    var res: [Int: (avg_time: Double, count: Int, std_time: Double)] = [:]

    var seq: Multiset<String>  = []


    let factory = MFDDFactory<Key,String>()
    
    var times: [Double] = []
    var s: Stopwatch = Stopwatch()
    var count = 0
    
    for len in nb_el_in_place {
      for i in 0..<len {
        seq.insert(String(i))
      }
      let marking1 = Marking<P1>([.p1: seq, .p2: ["add","sub","mul","div"], .res: []])
      print("Nb P1: \(len)")
      for i in 0 ..< test_number {
        print("Try nb: \(i)")
        s.reset()
        let x = model.fireableBindings(for: .apply, with: marking1, factory: factory)
        times.append(s.elapsed.s)
        s.reset()
        count = x.count
      }
      let average = times.reduce(0, +) / Double(times.count)
      let standard_deviation: Double = times
        .map({(x: Double) -> Double in return (x - average)*(x - average)})
        .reduce(0, +)
        .squareRoot()
      res[len] = (average.truncate(places: 4), count, standard_deviation.truncate(places: 4))
      seq = []
      times = []

    }

    print("----------------------------------")
//    print(s.elapsed.humanFormat)
    for (key,value) in res.sorted(by: {$0.key < $1.key}) {
      print("Nb P1: \(key) / Temps: \(value.avg_time) s / Nombre d'état: \(value.count) / Ecart-type: \(value.std_time)")
    }
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

  func testPerformance2() {
    enum P1: Place {
      typealias Content = Multiset<String>
      case p1, p2, res
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
    
    let conditionList: [Pair<String>]? = nil

    let model = HeroNet<P1, T1>(
      .pre(from: .p1, to: .apply, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .apply, labeled: ["$x"]),
      .post(from: .apply, to: .res, labeled: ["$f($x,$y)"]),
      guards: [.apply: conditionList],
      interpreter: interpreter
    )

    // Number of tests
    let test_number = 1
        
    // How many values in the place
    //    let nb_el_in_place = [100,500,1000,2000,4000,6000]
    let nb_el_in_place = [2]
    var res: [Int: (avg_time: Double, count: Int, std_time: Double)] = [:]

    var seq: Multiset<String>  = []


    let factory = MFDDFactory<Key,String>()
    
    var times: [Double] = []
    var s: Stopwatch = Stopwatch()
    var count = 0
    
    for len in nb_el_in_place {
      for i in 0..<len {
        seq.insert(String(i))
      }
      let marking1 = Marking<P1>([.p1: seq, .p2: ["0","1","2","3"], .res: []])
      print("Nb P1: \(len)")
      for i in 0 ..< test_number {
        print("Try nb: \(i)")
        s.reset()
        let x = model.fireableBindings(for: .apply, with: marking1, factory: factory)
        print(x)
        times.append(s.elapsed.s)
        s.reset()
        count = x.count
      }
      let average = times.reduce(0, +) / Double(times.count)
      let standard_deviation: Double = times
        .map({(x: Double) -> Double in return (x - average)*(x - average)})
        .reduce(0, +)
        .squareRoot()
      res[len] = (average.truncate(places: 4), count, standard_deviation.truncate(places: 4))
      seq = []
      times = []

    }

    print("----------------------------------")
//    print(s.elapsed.humanFormat)
    for (key,value) in res.sorted(by: {$0.key < $1.key}) {
      print("Nb P1: \(key) / Temps: \(value.avg_time) s / Nombre d'état: \(value.count) / Ecart-type: \(value.std_time)")
    }
    print("----------------------------------")

  }
  
  func testPerformance4() {
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
    
//    let conditionList: [Pair<String>]? = [Pair("eq(mod($a,2),0)","true")]
    let conditionList: [Pair<String>]? = [Pair("add($a,5)","6"), Pair("eq($c,0)", "false"),Pair("mod($g($b,$c),2)", "0")]

    let model = HeroNet<P1, T1>(
      .pre(from: .op, to: .apply, labeled: ["$f","$g"]),
      .pre(from: .n, to: .apply, labeled: ["$a","$b", "$c", "$d"]),
      .post(from: .apply, to: .res, labeled: ["$f($a,$b)"]),
      .post(from: .apply, to: .op, labeled: ["$f", "$g"]),
      guards: [.apply: conditionList],
      interpreter: interpreter
    )

    let len = 5

    var seq: Multiset<String>  = []
    for i in 0...len {
      seq.insert(String(i))
    }

    let factory = MFDDFactory<Key,String>()
    let marking1 = Marking<P1>([.op: ["add","sub","mul","div"], .n: seq, .res: []])


    let s: Stopwatch = Stopwatch()

    let x = model.fireableBindings(for: .apply, with: marking1, factory: factory)
    print(x.count)
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

