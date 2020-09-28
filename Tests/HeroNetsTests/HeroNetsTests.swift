import XCTest
@testable import HeroNets
import Interpreter

final class HeroNetsTests: XCTestCase {
  func testExample() {
      
//      typealias Place = String
////      let p1 = Place(name: "p1", values: ["1": 2, "2": 4])
////      let p2 = Place(name: "p2", values: [:])
//
//      let places: Set<Place> = ["p1","p2"]
//      let guards: [Transition.Condition] = [Transition.Condition(e1: "$x*2", e2: "y")]
//
//      let t1 = Transition(name: "t1", guards: guards, inArcs: [Transition.InArc(variables: ["x", "y"], place: "p1")], outArcs: [Transition.OutArc(expr: "add(x,y)", place: "p2")]
//      )
//
//      let transitions: Set<Transition> = [t1]
//
//      let marking: [Place: [String: Int]] = ["p1": ["2": 2, "4":1], "p2": [:]]
//
//      let module: String = """
//      func add(_ x: Int, _ y: Int) -> Int ::
//        x + y
//      """
//
//
//      var interpreter = Interpreter()
//      try! interpreter.loadModule(fromString: module)
//
//      let heroNet =  HeroNet(places: places, transitions: transitions, marking: marking, interpreter: interpreter)
//
//      print(try! heroNet.transitions.first?.isFireable(marking: marking, binding: ["x":"2", "y":"4"], interpreter: interpreter))
//
//      // print(heroNet.transitions.first?.checkGuards(binding: ["x": "2", "y": "2"], interpreter: interpreter))
  }
      
  enum P: Place {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1
  }
  
  func testNew() {
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["x","y"]),
      .pre(from: .p3, to: .t1, labeled: ["z"]),
      .post(from: .t1, to: .p2, labeled: ["y"])
    )
    
    let marking1 = Marking<P>([.p1: ["18", "42", "99"], .p2: ["2","2"], .p3: ["1","4"]])
    let marking2 = Marking<P>([.p1: ["1", "2"], .p2: ["2"], .p3: [:]])
    let marking3 = Marking<P>([.p1: ["2", "2", "1"], .p2: ["2","2"], .p3: ["3"]])


    let m1: Multiset<String> = ["x", "x", "y", "y"]
    let m2: Multiset<String> = ["y", "y", "x", "x"]
    
    let m3: Multiset<String> = [:]
    let m4: Multiset<String> = ["2":2]
    
//    let m3: Multiset<String> = ["x": 2, "y": 3]
    
//    print(marking3 - marking1)
//    print(m1 > m2)
//    print(marking1 < marking3)
//    print(m3)
//
//    marking1 += marking2
//    print(marking1 + marking2)
    
    
      print(model.fire(transition: .t1, from: marking1, with: ["x": "18", "y": "42", "z": "4"]))

//    print(marking1 <= marking2)
    
  }

  static var allTests = [
      ("testExample", testExample),
  ]
}
