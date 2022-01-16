import DDKit
///// A Hero net marking in the form of a MFDD

extension Marking where PlaceType.Content == Multiset<Val>, PlaceType: Comparable {
  
  public typealias KeyMarking = PlaceType
  public typealias ValueMarking = PlaceType.Content
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
  func markingToMFDDMarking(markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {
    var take: [ValueMarking: MarkingMFDD.Pointer] = [:]
    var res: MarkingMFDD.Pointer = markingMFDDFactory.one.pointer
    for place in PlaceType.allCases.sorted(by: {$0 > $1}) {
      take[self[place]] = res
      res = markingMFDDFactory.node(
        key: place,
        take: take,
        skip: markingMFDDFactory.zero.pointer
      )
      take = [:]
    }
    return MarkingMFDD(pointer: res, factory: markingMFDDFactory)
  }
  
}
