import DDKit
///// A Hero net marking in the form of a MFDD

extension Marking where PlaceType.Content == Multiset<String> {
  
  public typealias KeyMarking = KeyMFDD<PlaceType>
  public typealias ValueMarking = Pair<PlaceType.Content.Key, Int>
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
  func markingToMFDD(markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {
    
//    for l in PlaceType.allCases {
//      print(self[l])
//    }
    
    return markingMFDDFactory.one
  }
  
}


//public struct MarkingMFDD<PlaceType>
//where PlaceType: Place, PlaceType.Content == Multiset<String> {
//
//  public typealias KeyMarking = Key<PlaceType>
//  public typealias ValueMarking = Pair<PlaceType.Content.Key, Int>
//  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
//  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
//
//
//  let factory: MarkingMFDDFactory
//  let markingMFDD: MarkingMFDD
//
//  public init (marking: Marking<PlaceType>, factory: MarkingMFDDFactory) {
//    self.markingMFDD = lol(marking: marking, factory: factory)
//    self.factory = factory
//  }
//
//  public func lol(marking: Marking<PlaceType>, factory: MarkingMFDDFactory) -> MarkingMFDD {
//    return factory.zero
//  }
////  let factory: Factory
//
//
//}
