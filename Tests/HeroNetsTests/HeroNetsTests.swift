import XCTest
@testable import HeroNets
import Interpreter

final class HeroNetsTests: XCTestCase {
    func testExample() {
      
      typealias Place = String
//      let p1 = Place(name: "p1", values: ["1": 2, "2": 4])
//      let p2 = Place(name: "p2", values: [:])
      
      let places: Set<Place> = ["p1","p2"]
      let guards: Set<Transition.Condition>? = [Transition.Condition(e1: "x", e2: "y")]
      
      let t1 = Transition(name: "t1", guards: guards, inArcs: [Transition.InArc(variables: ["x", "y"], place: "p1")], outArcs: [Transition.OutArc(expr: "add(x,y)", place: "p2")]
      )
      
      let transitions: Set<Transition> = [t1]
      
      let marking: [Place: [String: Int]] = ["p1": ["2": 2, "3":1], "p2": [:]]
      
      let module: String = """
      func add(_ x: Int, _ y: Int) -> Int ::
        x + y
      """
      
      
      var interpreter = Interpreter()
      try! interpreter.loadModule(fromString: module)
          
      let heroNet =  HeroNet(places: places, transitions: transitions, marking: marking, interpreter: interpreter)
      
      print(try! heroNet.transitions.first?.isFireable(marking: marking, binding: ["x":"2", "y":"2"]))
      
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
