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
      case t1, t2
    }
  
    typealias KeyMarking = P
    typealias ValueMarking = P.Content
    typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
    typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
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
  
  func testExcludingFilter() {
    
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    var marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    var markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    
    var ms: Multiset<Val> = ["1"]
    var excludeFilter = morphisms.filterMarking(excluding: [(key: .p1, value: ms)])
    var expectedRes: [[KeyMarking: ValueMarking]] = [[.p1: ["1", "2","3"], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
    
    excludeFilter = morphisms.filterMarking(excluding: [(key: .p1, value: ms), (key: .p2, value: ms)])
    expectedRes = [[.p1: ["1", "2","3"], .p2: ["1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
    
    ms = ["1", "1", "2","3"]
    excludeFilter = morphisms.filterMarking(excluding: [(key: .p1, value: ms)])
    expectedRes = [[.p1: [], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)

    ms = ["42"]
    excludeFilter = morphisms.filterMarking(excluding: [(key: .p1, value: ms)])
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), computeUnfoldMarking(markingMFDD))
    
    marking = Marking<P>([.p1: [], .p2: [], .p3: ["42"]])
    markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    ms = ["42"]
    excludeFilter = morphisms.filterMarking(excluding: [(key: .p3, value: ms)])
    expectedRes = [[.p1: [], .p2: [], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(excludeFilter.apply(on: markingMFDD)), expectedRes)
  }
  
  func testInsert() {
    
    let markingMFDDFactory = MarkingMFDDFactory()
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }

    let marking = Marking<P>([.p1: ["1", "1", "2","3"], .p2: ["1", "1", "2"], .p3: []])
    let markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    
    var ms: Multiset<Val> = ["1"]
    var insertMarking = morphisms.insertMarking(insert: [(key: .p1, value: ms)])
    var expectedRes: [[KeyMarking: ValueMarking]] = [[.p1: ["1", "1", "1", "2", "3"], .p2: ["1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(insertMarking.apply(on: markingMFDD)), expectedRes)
    
    insertMarking = morphisms.insertMarking(insert: [(key: .p1, value: ms), (key: .p2, value: ms)])
    expectedRes = [[.p1: ["1", "1", "1", "2","3"], .p2: ["1", "1", "1", "2"], .p3: []]]
    XCTAssertEqual(computeUnfoldMarking(insertMarking.apply(on: markingMFDD)), expectedRes)

    ms = ["42"]
    insertMarking = morphisms.insertMarking(insert: [(key: .p1, value: ms), (key: .p3, value: ms)])
    expectedRes = [[.p1: ["1", "1", "2","3", "42"], .p2: ["1", "1", "2"], .p3: ["42"]]]
    XCTAssertEqual(computeUnfoldMarking(insertMarking.apply(on: markingMFDD)), expectedRes)
        
  }

}
