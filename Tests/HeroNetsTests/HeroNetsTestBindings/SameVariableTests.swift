import Interpreter
import DDKit
@testable import HeroNets
import XCTest

final class SameVariableTests: XCTestCase {
  
  typealias Label = String
  typealias KeyMFDD = Key<String>
  typealias ValueMFDD = String
  
  enum P: Place, Equatable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  // Transform mfdd into a set of dictionnaries with all possibilities
  func simplifyBinding(bindings: MFDD<KeyMFDD,ValueMFDD>) -> Set<[String:String]> {
    
    var bindingSimplify: Set<[String: String]> = []
    var dicTemp: [String: String] = [:]
    
    for el in bindings {
      for (k,v) in el {
        dicTemp[k.label] = v
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

//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)

//    let conditionList: [Pair<String>]? = nil

    let conditionList: [Pair<String>] = [Pair("$x","1"), Pair("$x", "$z")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$y"]),
//      .pre(from: .p2, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$x", "$z"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: conditionList, .t2: nil],
      module: module
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2"], .p2: ["1", "1", "2"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)

    // Cas bug: [$y, $z, $x]
    print(mfdd)
    print(mfdd.count)
   }

  func testBinding01() {

    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

//    var interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: module)

//    let conditionList: [Pair<String>]? = nil

//    let conditionList: [Pair<String>] = [Pair("$y","1"), Pair("$x", "$z")]
    let conditionList: [Pair<String>] = [Pair("$x","1")]

    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x", "$x"]),
//      .pre(from: .p2, to: .t1, labeled: ["$x", "2"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p3, labeled: ["$x"]),
      guards: [.t1: conditionList, .t2: nil],
      module: module
    )

    let marking1 = Marking<P>([.p1: ["1", "1", "2", "4"], .p2: ["1", "2", "3"], .p3: []])

    print("----------------------------")

    let factory = MFDDFactory<KeyMFDD,ValueMFDD>()

    let mfdd = model.fireableBindings(for: .t1, with: marking1, factory: factory)
    
    print(mfdd)
   }
  
  
}

