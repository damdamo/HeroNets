import XCTest
@testable import HeroNets
import Interpreter
import DDKit


final class MarkingHomomorphismTests: XCTestCase {
  
  enum P: Place, Hashable, Comparable, CustomStringConvertible {
    typealias Content = Multiset<Val>
    case p1,p2,p3

    public var description: String {
      switch self {
      case .p1:
        return "p1"
      case .p2:
        return "p2"
      case .p3:
        return "p3"
      }
    }
  }

  enum T: Transition {
    case t1//, t2
  }

  typealias KeyMarking = P
  typealias ValueMarking = P.Content
  typealias MarkingMFDD = MFDD<KeyMarking, ValueMarking>
  typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  typealias Var = String
  typealias KeyMFDDVar = KeyMFDD<Var>
  typealias BindingMFDD = MFDD<KeyMFDDVar, Val>
  typealias BindingMFDDFactory = MFDDFactory<KeyMFDDVar, Val>
  
  let f = ILang.var("$f")
  let g = ILang.var("$g")
  let x = ILang.var("$x")
  let y = ILang.var("$y")
  let z = ILang.var("$z")
  
  // Transform mfdd into a marking, i.e. a dictionnary with all values for each place.
  func computeUnfoldMarking(_ markingMFDD: MarkingMFDD) -> [[KeyMarking: ValueMarking]] {
    var unfoldMarking: [[KeyMarking: ValueMarking]] = []
    for el in markingMFDD {
      unfoldMarking.append(el)
    }
    return unfoldMarking
  }
  
  func testMarkingMFDD0() {
  
  //    let interpreter = Interpreter()
    let markingMFDDFactory = MarkingMFDDFactory()
    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
  
    let res = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    let expectedRes: [[KeyMarking: ValueMarking]] = [[.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(res), expectedRes)
    
  }
  
  func testRemoveValuesInMarking() {
    
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    var marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    var markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    
    var ms: Multiset<Val> = ["1"]
    var excludeFilter = morphisms.removeValuesInMarking(excluding: [(key: .p1, value: ms)])
    var expectedRes: [[KeyMarking: ValueMarking]] = [[.p1: ["1", "2","3"], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
    
    excludeFilter = morphisms.removeValuesInMarking(excluding: [(key: .p1, value: ms), (key: .p2, value: ms)])
    expectedRes = [[.p1: ["1", "2","3"], .p2: ["1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
    
    ms = ["1", "1", "2","3"]
    excludeFilter = morphisms.removeValuesInMarking(excluding: [(key: .p1, value: ms)])
    expectedRes = [[.p1: [], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)

    ms = ["42"]
    excludeFilter = morphisms.removeValuesInMarking(excluding: [(key: .p1, value: ms)])
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), computeUnfoldMarking(markingMFDD))
    
    marking = Marking<P>([.p1: [], .p2: [], .p3: ["42"]])
    markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    ms = ["42"]
    excludeFilter = morphisms.removeValuesInMarking(excluding: [(key: .p3, value: ms)])
    expectedRes = [[.p1: [], .p2: [], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
  }
  
  func testInsert() {
    
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    let markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    
    var ms: Multiset<Val> = ["1"]
    var insertValuesInMarking = morphisms.insertValuesInMarking(insert: [(key: .p1, value: ms)])
    var expectedRes: [[KeyMarking: ValueMarking]] = [[.p1: ["1", "1", "1", "2", "3"], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(insertValuesInMarking.apply(on: markingMFDD)), expectedRes)
    
    insertValuesInMarking = morphisms.insertValuesInMarking(insert: [(key: .p1, value: ms), (key: .p2, value: ms)])
    expectedRes = [[.p1: ["1", "1", "1", "2","3"], .p2: ["1", "1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(insertValuesInMarking.apply(on: markingMFDD)), expectedRes)

    ms = ["42"]
    insertValuesInMarking = morphisms.insertValuesInMarking(insert: [(key: .p1, value: ms), (key: .p3, value: ms)])
    expectedRes = [[.p1: ["1", "1", "2","3", "42"], .p2: ["1", "1", "2"], .p3: ["42"]]]
    XCTAssertEqual(computeUnfoldMarking(insertValuesInMarking.apply(on: markingMFDD)), expectedRes)
        
  }
  
  func testFire() {
    let module: String = """
    func add(_ x: Int, _ y: Int) -> Int ::
      x + y
    """

    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    var model = HeroNet<P, T>(
      .pre(from: .p1, to: .t1, labeled: [x,y]),
      .pre(from: .p2, to: .t1, labeled: [z]),
      .post(from: .t1, to: .p3, labeled: [.exp("$x+$y")]),
      guards: [.t1: nil],
//      guards: [.t1: [Pair(x,z), Pair(x, .exp("$y-1"))]],
      interpreter: interpreter
    )
    
    let bindingMFDDFactory = BindingMFDDFactory()
    let markingMFDDFactory = MarkingMFDDFactory()
    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    let markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    let expectedRes = Marking<P>([.p1: ["2","3"], .p2: ["1", "1"], .p3:["2"]]).markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)

    let binding: [String: Val] = ["$x": "1", "$y": "1", "$z": "2"]
    XCTAssertEqual(model.fireHom(transition: .t1, binding: binding, markingMFDDFactory: markingMFDDFactory).apply(on: markingMFDD), expectedRes)
    
    let allBindings = model.fireAllBindingsHom(transition: .t1, from: marking, markingMFDDFactory: markingMFDDFactory, bindingMFDDFactory: bindingMFDDFactory).apply(on: markingMFDD)
    let expectedAllBindings = model.fireAllEnabledBindingsSimple(transition: .t1, from: marking, heroMFDDFactory: bindingMFDDFactory)
    XCTAssertEqual(allBindings.count, expectedAllBindings.count)
    
  }
  
  func testRemoveValueInMarking() {
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    var marking1 = Marking<P>([.p1: ["1","2"], .p2: ["3", "4"], .p3: []])
    var marking2 = Marking<P>([.p1: ["1","5"], .p2: ["6", "7"], .p3: []])
    
    var markingMFDD = marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    markingMFDD = markingMFDD.union(marking2.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))

    let valueToRemove: Val = .cst("1")
    let removeFilter = morphisms.removeValueInMarking(assignment: (key: .p1, value: valueToRemove))
    
    marking1 = Marking<P>([.p1: ["2"], .p2: ["3", "4"], .p3: []])
    marking2 = Marking<P>([.p1: ["5"], .p2: ["6", "7"], .p3: []])
    
    let expectedRes = marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory).union(marking2.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))
    
    XCTAssertEqual(removeFilter.apply(on: markingMFDD), expectedRes)
  }
  
  
  func testInsertValueInMarking() {
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    var marking1 = Marking<P>([.p1: ["2"], .p2: ["3", "4"], .p3: []])
    var marking2 = Marking<P>([.p1: ["5"], .p2: ["6", "7"], .p3: []])
    
    var markingMFDD = marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    markingMFDD = markingMFDD.union(marking2.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))

    let valueToInsert: Val = .cst("1")
    let insertFilter = morphisms.insertValueInMarking(assignment: (key: .p1, value: valueToInsert))
    
    marking1 = Marking<P>([.p1: ["1","2"], .p2: ["3", "4"], .p3: []])
    marking2 = Marking<P>([.p1: ["1","5"], .p2: ["6", "7"], .p3: []])
    
    let expectedRes = marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory).union(marking2.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))
    
    XCTAssertEqual(insertFilter.apply(on: markingMFDD), expectedRes)
  }
  
  func testFilterMarking() {
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let marking1 = Marking<P>([.p1: ["1","2"], .p2: ["3", "4"], .p3: []])
    let marking2 = Marking<P>([.p1: ["1","5"], .p2: ["6", "7"], .p3: []])
    
    var markingMFDD = marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    markingMFDD = markingMFDD.union(marking2.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))

    var valueToFilter: Val = .cst("1")
    var filterMorphism = morphisms.filterMarking(include: (key: .p1, value: valueToFilter))
    
    XCTAssertEqual(filterMorphism.apply(on: markingMFDD), markingMFDD)
    
    valueToFilter = .cst("2")
    filterMorphism = morphisms.filterMarking(include: (key: .p1, value: valueToFilter))
    
    XCTAssertEqual(filterMorphism.apply(on: markingMFDD), marking1.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory))
    
    valueToFilter = .cst("3")
    filterMorphism = morphisms.filterMarking(include: (key: .p1, value: valueToFilter))
    
    XCTAssertEqual(filterMorphism.apply(on: markingMFDD), markingMFDDFactory.zero)
  }

}
