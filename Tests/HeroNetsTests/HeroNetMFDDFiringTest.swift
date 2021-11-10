import XCTest
@testable import HeroNets
import Interpreter
import DDKit

final class AllFiringTests: XCTestCase {
  
  enum P: Place, Hashable, Comparable {
    typealias Content = Multiset<String>
    
    case p1,p2,p3
  }
  
  enum T: Transition {
    case t1, t2
  }
  
  typealias KeyMarking = P
  typealias ValueMarking = Pair<P.Content.Key, Int>
  typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
  // Transform mfdd into a marking, i.e. a dictionnary with all values for each place.
  func simplifyMarking(marking: MFDD<P, Pair<String, Int>>) -> [String: Multiset<String>] {
    
    var bindingSimplify: [String: Multiset<String>] = [:]
    var setPairPerPlace: [P: Set<Pair<String,Int>>] = [:]
    
    for place in P.allCases {
      bindingSimplify["\(place)"] = []
      setPairPerPlace[place] = []
    }
    
    for el in marking {
      for (k,v) in el {
        setPairPerPlace[k]!.insert(v)
      }
    }
    
    for (place, values) in setPairPerPlace {
      for value in values {
        bindingSimplify["\(place)"]!.insert(value.l, occurences: value.r)
      }
    }
    
    return bindingSimplify
  }
  
  func testIsFireable() {
    
    enum P: Place, Comparable {
      typealias Content = Multiset<String>
      
      case p1,p2,p3,p4
    }
    
    enum T: Transition {
      case t1
    }
    
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x","$y"]),
      .pre(from: .p2, to: .t1, labeled: ["$x"]),
      .post(from: .t1, to: .p3, labeled: ["$x"]),
      .post(from: .t1, to: .p4, labeled: ["$x+$y"]),
      guards: [.t1: nil],
      interpreter: interpreter
    )
    
    let marking1 = Marking<P>([.p1: ["1","2"], .p2: ["1", "2"], .p3: [], .p4: []])
    
    var expectedRes: Set<Marking<P>> = []
    expectedRes.insert([.p1: ["1","2"], .p2: ["1", "2"], .p3: [], .p4: []])
    expectedRes.insert([.p1: [], .p2: ["1"], .p3: ["2"], .p4: ["3"]])
    expectedRes.insert([.p1: [], .p2: ["2"], .p3: ["1"], .p4: ["3"]])
    
    XCTAssertEqual(model.generateAllFiring(for: .t1, with: marking1), expectedRes)
  }
  
  func testLol() {
    
    let markingMFDDFactory = MFDDFactory<P, Pair<String, Int>>()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    let interpreter = Interpreter()
//    try! interpreter.loadModule(fromString: "")
    
    let model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: ["$x"]),
      .pre(from: .p2, to: .t1, labeled: ["$y"]),
      .post(from: .t1, to: .p3, labeled: ["$x+$y"]),
      guards: [.t1: nil, .t2: nil],
      interpreter: interpreter
    )
    
    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
   
    let res = model.fire(transition: .t1, from: marking, with: ["$x": "1", "$y": "2"], markingMFDDFactory: markingMFDDFactory)
    
    print(simplifyMarking(marking: res))
  }
  
  
  
  
  static var allTests = [
    ("testIsFireable", testIsFireable),
  ]
}
