import DDKit
///// A Hero net marking in the form of a MFDD

extension Marking where PlaceType.Content == Multiset<String>, PlaceType: Comparable {
  
  public typealias KeyMarking = PlaceType
  public typealias ValueMarking = Pair<PlaceType.Content.Key, Int>
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
  public func markingToMFDD(markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {
    
    return MarkingMFDD(
      pointer: createMarkingMFDD(places: PlaceType.allCases as! [PlaceType], markingMFDDFactory: markingMFDDFactory),
      factory: markingMFDDFactory
    )
    
  }
  
  func createMarkingMFDD(places: [PlaceType], markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD.Pointer {
    
    if let place = places.first {
      var take: [ValueMarking: MarkingMFDD.Pointer] = [:]
      let p = createMarkingMFDD(places: Array(places.dropFirst()), markingMFDDFactory: markingMFDDFactory)
      
      if self[place].isEmpty {
        return markingMFDDFactory.node(key: place, take: [:], skip: p)
      }
      for el in self[place].distinctMembers {
        take[Pair(el, self[place].occurences(of: el))] = p
      }
      
      return markingMFDDFactory.node(key: place, take: take, skip:  markingMFDDFactory.zero.pointer)
    }
    
    return markingMFDDFactory.one.pointer
  }
  
}
