import DDKit
/// A Hero net marking in the form of a MFDD

public struct MarkingMFDD<PlaceType>
where PlaceType: Place, PlaceType.Content == Multiset<String> {
  
  public typealias KeyMarking = Key<PlaceType>
  public typealias ValueMarking = (PlaceType.Content.Key, Int)
//  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>

//  let factory: Factory
  
  
}
