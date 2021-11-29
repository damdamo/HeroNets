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
  
  public func mfddToMarking(markingMFDD: MarkingMFDD, markingMFDDFactory: MarkingMFDDFactory) -> Marking<KeyMarking>{
    
    var res: [PlaceType: Multiset<String>] = [:]
    var multisetTemp: Multiset<String> = []
    var pointer = markingMFDD.pointer
    
    for place in PlaceType.allCases {
      res[place] = [:]
    }
    
    while pointer != markingMFDDFactory.one.pointer || pointer == markingMFDDFactory.zero.pointer {
      for (key, _) in pointer.pointee.take {
        multisetTemp.insert(key.l, occurences: key.r)
      }
      res[pointer.pointee.key] = multisetTemp
      multisetTemp = []
      
      if let next = pointer.pointee.take.first?.value {
        pointer = next
      } else {
        pointer = pointer.pointee.skip
      }
    }
    
    return Marking<KeyMarking>(res)
  }
  
  
  // Transform mfdd into a marking, i.e. a dictionnary with all values for each place.
//  func simplifyMarking(marking: MFDD<P, Pair<String, Int>>) -> [String: Multiset<String>] {
//
//    var bindingSimplify: [String: Multiset<String>] = [:]
//    var setPairPerPlace: [P: Set<Pair<String,Int>>] = [:]
//
//    for place in P.allCases {
//      bindingSimplify["\(place)"] = []
//      setPairPerPlace[place] = []
//    }
//
//    for el in marking {
//      for (k,v) in el {
//        setPairPerPlace[k]!.insert(v)
//      }
//    }
//
//    for (place, values) in setPairPerPlace {
//      for value in values {
//        bindingSimplify["\(place)"]!.insert(value.l, occurences: value.r)
//      }
//    }
//
//    return bindingSimplify
//  }
  
  private func createMarkingMFDD(places: [PlaceType], markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD.Pointer {
    
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
