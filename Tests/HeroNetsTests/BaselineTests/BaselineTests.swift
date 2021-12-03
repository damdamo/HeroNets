//import Interpreter
//import DDKit
//@testable import HeroNets
//import XCTest
//
//final class BaselineTests: XCTestCase {
//  
//  typealias Label = String
//  typealias Value = String
//  
//  enum P: Place, Equatable {
//    typealias Content = Multiset<String>
//    
//    case p1,p2,p3
//  }
//  
//  enum T: Transition {
//    case t1
//  }
//  
//  
//  func testWithSameVariableInAllArcs() {
//    let module = ""
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//    
//    let conditionList: [Pair<String, String>]? = nil
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$x"]),
//      .pre(from: .p3, to: .t1, labeled: ["$x"]),
//      guards: [.t1: conditionList],
//      interpreter: interpreter
//    )
//    
//    let baseline = Baseline(heroNet: model)
//    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "4", "5"], .p3: ["1", "2", "4"]])
//    
////    print(baseline.setUniqueVariableForATransition(transition: .t1, net: model))
//    
////    let t = baseline.computeBindingsForAPlaceBF(labels: ["x","y"], placeValues: ["1","2","3","4","5"])
////    print(t)
////    print(t.count)
//    
////    let toto = baseline.fireableBindingsBF(transition: .t1, marking: marking, net: model)
//    let toto = baseline.bindingBruteForceWithOptimizedNet(transition: .t1, marking: marking)
//    
//    print(toto)
//    print(toto.count)
//    
////    let mfdd = model.fireableBindings(for: .t1, with: marking, factory: factory)
////    let expectedRes: Set<[String:String]> = [["$y": "3", "$x": "2"], ["$x": "1", "$y": "3"], ["$x": "2", "$y": "1"], ["$y": "2", "$x": "1"]]
////    XCTAssertEqual(simplifyBinding(bindings: mfdd), expectedRes)
//  }
//  
//  // Conditions + same variables + constant + independant variable + constant propagation
//  func testBinding4() {
//
//    let module: String = """
//    func add(_ x: Int, _ y: Int) -> Int ::
//      x + y
//    """
//    
//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)
//
//    let conditionList = [Pair("$x","$y-1"), Pair("$y", "$z"), Pair("$a", "1")]
//
//    let model = HeroNet<P, T>(
//      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$z", "$a"]),
//      .pre(from: .p3, to: .t1, labeled: ["$b", "3"]),
//      guards: [.t1: conditionList],
//      interpreter: interpreter
//    )
//    
//    let marking = Marking<P>([.p1: ["1", "2", "3"], .p2: ["1", "2", "3", "4"], .p3: ["1", "3"]])
//    let baseline = Baseline(heroNet: model)
//    let bindings = baseline.bindingBruteForceWithOptimizedNet(transition: .t1, marking: marking)
//    
//    let expectedRes = Set([["$x": "1", "$b": "1", "$z": "2"], ["$b": "1", "$x": "2", "$z": "3"]])
//    
//    XCTAssertEqual(bindings, expectedRes)
//  }
//  
//}
//
