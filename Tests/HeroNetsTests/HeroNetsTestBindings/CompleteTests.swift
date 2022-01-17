import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class HeroNetsBindingsTests: XCTestCase {
  
  let a = ILang.var("$a")
  let b = ILang.var("$b")
  let f = ILang.var("$f")
  let g = ILang.var("$g")
  let x = ILang.var("$x")
  let y = ILang.var("$y")
  let z = ILang.var("$z")
  
  typealias Var = String
  typealias KeyMFDDVar = KeyMFDD<Var>
  typealias ValueMFDD = Val
  typealias Guard = Pair<ILang, ILang>
  
  enum P: Place, Equatable {
    typealias Content = Multiset<Val>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  // Transform mfdd into a set of dictionnaries with all possibilities
  func simplifyBinding(bindings: MFDD<KeyMFDDVar,ValueMFDD>) -> Set<[String:String]> {
    
    var bindingSimplify: Set<[String: String]> = []
    var dicTemp: [String: String] = [:]
    
    for el in bindings {
      for (k,v) in el {
        dicTemp[k.label] = v.description
      }
      bindingSimplify.insert(dicTemp)
      dicTemp = [:]
    }
    
    return bindingSimplify
  }
  
  func testBinding0() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """
    
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList = [Pair(x, .val("1")), Pair(x, z)]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
//      .pre(from: .p2, to: .t1, labeled: [x, "2"]),
      .pre(from: .p2, to: .t1, labeled: [x, z]),
      .post(from: .t1, to: .p3, labeled: [.exp("$x+$y")]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["1", "1", "2"], .p2: ["1", "1", "2"], .p3: []])
    
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)

   }

  func testBinding01() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

//    let conditionList = [Pair(y,"1"), Pair(x, z)]
    let conditionList: [Guard] = [Pair(x, .val("1"))]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, x]),
      .pre(from: .p2, to: .t1, labeled: [x, .val("2")]),
//      .pre(from: .p2, to: .t1, labeled: [x]),
      .post(from: .t1, to: .p3, labeled: [x]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2", "4"], .p2: ["1", "2", "3"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    
    print(mfdd)
   }
  
  // Test with guards and a constant on an arc
  func testBinding1() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList = [Pair(x, .val("1")), Pair(y, z)]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x,y]),
      .pre(from: .p2, to: .t1, labeled: [z, .val("3")]),
      .post(from: .t1, to: .p3, labeled: [.exp("$x+$y")]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let marking1 = Marking<P>([.p1: ["1","1","2","3"], .p2: ["1", "2", "3"], .p3: []])

    let bindings = model.fireableBindings(for: .t1, with: marking1, factory: factory)
      
    let bindingSimplified = simplifyBinding(bindings: bindings)
    let expectedRes: Set<[String:String]> = [["$z": "1"], ["$z": "2"]]

    XCTAssertEqual(bindingSimplified, expectedRes)

  }

  // Two different transitions firing
  func testBinding2() {

    enum P2: Place {
      typealias Content = Multiset<Val>
      case op, p1, p2, res
    }

    enum T2: Transition {
      case curry, apply
    }

    let module: String = """
    func add(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x + y

    func sub(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x - y

    func mul(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x * y

    func div(_ x: Int) -> (Int) -> Int ::
      func foo(_ y: Int) -> Int ::
        x / y

    func eq(_ n1: Int, _ n2: Int) -> Bool ::
    // Equality between two numbers
      if n1 = n2
        then true
        else false
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionListCurry: [Guard] = [Pair(f, .val("div"))]
    let conditionListApply: [Guard] = [Pair(.exp("eq($y,0)"), .val("false"))]

    let model = HeroNet<P2, T2>(
      .pre(from: .op, to: .curry, labeled: [f]),
      .pre(from: .p1, to: .curry, labeled: [x]),
      .pre(from: .p1, to: .apply, labeled: [y]),
      .pre(from: .p2, to: .apply, labeled: [g]),
      .post(from: .curry, to: .p2, labeled: [.exp("$f($x)")]),
      .post(from: .apply, to: .res, labeled: [.exp("$g($y)")]),
      guards: [.curry: conditionListCurry, .apply: conditionListApply],
      interpreter: interpreter
    )

    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let marking1 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["1", "1", "2"], .p2: [], .res: []])
    let marking2 = Marking<P2>([.op: ["add","sub","mul","div"], .p1: ["0", "1"], .p2: ["div(2)"], .res: []])

    let bindings1: MFDD<KeyMFDDVar,ValueMFDD> = model.fireableBindings(for: .curry, with: marking1, factory: factory)
    let bindings2: MFDD<KeyMFDDVar,ValueMFDD> = model.fireableBindings(for: .apply, with: marking2, factory: factory)
    
    XCTAssertEqual(simplifyBinding(bindings: bindings1), Set([["$x": "1"], ["$x": "2"]]))
    XCTAssertEqual(simplifyBinding(bindings: bindings2), Set([["$y": "1", "$g": "div(2)"]]))
  }
  
  // Conditions + same variables + constant
  func testBinding3() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let conditionList: [Guard] = [Pair(x,.exp("$y-1")), Pair(y, z)]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, x]),
      .pre(from: .p2, to: .t1, labeled: [y]),
      .pre(from: .p3, to: .t1, labeled: [z, .val("3")]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2", "2", "3", "3"], .p2: ["1", "2", "3"], .p3: ["1", "2", "3"]])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let expectedRes = Set([["$z": "2", "$x": "1"]])
    
    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
  }

  // Conditions + same variables + constant + independant variable + constant propagation
  func testBinding4() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """
    
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    let conditionList: [Guard] = [Pair(x,.exp("$y-1")), Pair(y, z), Pair(a, .val("1"))]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x, y]),
      .pre(from: .p2, to: .t1, labeled: [z, a]),
      .pre(from: .p3, to: .t1, labeled: [b, .val("3")]),
      guards: [.t1: conditionList, .t2: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "3", "4"], .p3: ["1", "3"]])
    let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()
    let expectedRes = Set([["$x": "1", "$b": "1", "$z": "2"], ["$b": "1", "$x": "2", "$z": "3"]])
    
    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
    
  }
  
  func testDiningPhilosopher() {
    enum P: Place, Comparable {
      typealias Content = Multiset<Val>
      case think, eat, fork
    }
    enum T: Transition {
      case thinkToEat, eatToThink
    }
    
    var interpreter = Interpreter()
    let module = """
    func mod(_ x: Int, _ y: Int) -> Int ::
      if x < y then x else mod(x-y,y)
    """
    try! interpreter.loadModule(fromString: module)
    let p = ILang.var("$p")
    let f1 = ILang.var("$f1")
    let f2 = ILang.var("$f2")
    var len = 1
    var conditions: [Pair<ILang,ILang>]? = [Pair(f1,p), Pair(f2, .exp("mod($p+1, \(len))"))]
    var model = HeroNet<P, T>(
      .pre(from: .think, to: .thinkToEat, labeled: [p]),
      .pre(from: .fork, to: .thinkToEat, labeled: [f1, f2]),
      .post(from: .thinkToEat, to: .eat, labeled: [p]),
      .pre(from: .eat, to: .eatToThink, labeled: [p]),
      .post(from: .eatToThink, to: .think, labeled: [p]),
      .post(from: .eatToThink, to: .fork, labeled: [p, .exp("mod($p+1,\(len))")]),
      guards: [.thinkToEat: conditions, .eatToThink: nil],
      interpreter: interpreter
    )
    
    // CSS
//    let factory = MFDDFactory<P, Pair<P.Content.Key, Int>>()
    // Binding
    let factory = MFDDFactory<KeyMFDD<String>,Val>()
    var marking: Marking<P>
    var seq: Multiset<Val>  = []
   
    for i in 0 ..< len {
      seq.insert(Val.init(stringLiteral: i.description))
    }
    marking = Marking([.think: seq, .eat: [], .fork: seq])
    XCTAssertEqual(factory.zero, model.fireableBindings(for: .thinkToEat, with: marking, factory: factory))
    
    len = 3
    conditions = [Pair(f1,p), Pair(f2, .exp("mod($p+1,\(len))"))]
    model = HeroNet<P, T>(
      .pre(from: .think, to: .thinkToEat, labeled: [p]),
      .pre(from: .fork, to: .thinkToEat, labeled: [f1, f2]),
      .post(from: .thinkToEat, to: .eat, labeled: [p]),
      .pre(from: .eat, to: .eatToThink, labeled: [p]),
      .post(from: .eatToThink, to: .think, labeled: [p]),
      .post(from: .eatToThink, to: .fork, labeled: [p, .exp("mod($p+1,\(len))")]),
      guards: [.thinkToEat: conditions, .eatToThink: nil],
      interpreter: interpreter
    )
    seq = []
    for i in 0 ..< len {
      seq.insert(Val.init(stringLiteral: i.description))
    }
    marking = Marking([.think: seq, .eat: [], .fork: seq])
    let expectedRes = Set([["$p": "0", "$f2": "1"], ["$p": "1", "$f2": "2"], ["$p": "2", "$f2": "0"]])
    let res = model.fireableBindings(for: .thinkToEat, with: marking, factory: factory)
    XCTAssertEqual(simplifyBinding(bindings: res), expectedRes)
    
    XCTAssertEqual(model.computeStateSpaceBF(from: marking).count, 4)
  }
  
  func testDiningPhilosopherPerf() {
    enum P: Place, Comparable {
      typealias Content = Multiset<Val>
      case think, eat, fork
    }
    enum T: Transition {
      case thinkToEat, eatToThink
    }
    
    var interpreter = Interpreter()
    let module = """
    func mod(_ x: Int, _ y: Int) -> Int ::
      if x < y then x else mod(x-y,y)
    """
    try! interpreter.loadModule(fromString: module)
    let p = ILang.var("$p")
    let f1 = ILang.var("$f1")
    let f2 = ILang.var("$f2")
    let len = 9
    let conditions: [Pair<ILang,ILang>]? = [Pair(f1,p), Pair(f2, .exp("mod($p+1, \(len))"))]
    let model = HeroNet<P, T>(
      .pre(from: .think, to: .thinkToEat, labeled: [p]),
      .pre(from: .fork, to: .thinkToEat, labeled: [f1, f2]),
      .post(from: .thinkToEat, to: .eat, labeled: [p]),
      .pre(from: .eat, to: .eatToThink, labeled: [p]),
      .post(from: .eatToThink, to: .think, labeled: [p]),
      .post(from: .eatToThink, to: .fork, labeled: [p, .exp("mod($p+1,\(len))")]),
      guards: [.thinkToEat: conditions, .eatToThink: nil],
      interpreter: interpreter
    )
    
    // CSS
//    let factory = MFDDFactory<P, Pair<P.Content.Key, Int>>()
    // Binding
//    let factory = MFDDFactory<KeyMFDD<String>,Val>()
    var marking: Marking<P>
    var seq: Multiset<Val>  = []
   
    for i in 0 ..< len {
      seq.insert(Val.init(stringLiteral: i.description))
    }
    marking = Marking([.think: seq, .eat: [], .fork: seq])
//    XCTAssertEqual(factory.zero, model.fireableBindings(for: .thinkToEat, with: marking, factory: factory))
    let s: Stopwatch = Stopwatch()
    model.computeStateSpaceBF(from: marking)
    print(s.elapsed.humanFormat)
  }
  
}

