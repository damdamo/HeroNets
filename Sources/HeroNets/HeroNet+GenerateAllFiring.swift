import DDKit

extension HeroNet where PlaceType: Comparable {
  
  public typealias KeyMarking = PlaceType
  public typealias ValueMarking = Pair<PlaceType.Content.Key, Int>
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  
  public func fire(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [Label: Value], markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {
    
    var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
    
    var elementsToFilter: [(key: PlaceType, values: [ValueMarking])] = []
    
    if let pre = input[transition] {
      for (place, labels) in pre {
        
        // Get the list of values using list of variables for each place
        let listeValues = labels.map({(label) in
          return binding[label]!
        })
 
        // Using the listValues, we transform it into a dictionnary that
        let dicValues = listeValues.reduce([:], {(currentDic, newValue) -> [Value: Int] in
          var dicTemp = currentDic
          if let _ = currentDic[newValue] {
            dicTemp[newValue]! += 1
          } else {
            dicTemp[newValue] = 1
          }
          
          return dicTemp
        })
        
        elementsToFilter.append((
          key: place,
          values: dicValues.map({(value, occurence) in
            Pair(value, occurence)
          })
        ))
        
      }
      print(elementsToFilter)
      let morphism = morphisms.filterMarking(excluding: elementsToFilter)
      let markingMFDD = marking.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
      return morphism.apply(on: markingMFDD)
      
    }
    
    return markingMFDDFactory.zero
    
  }
  
  public func generateAllFiring(for transition: TransitionType, with marking: Marking<PlaceType>)
  -> Set<Marking<PlaceType>>
  {
    
    let factory = HeroMFDDFactory()
    let netStaticOptimized = computeStaticOptimizedNet(transition: transition)
    
    if let netStaticOptimized = netStaticOptimized {
      let allBindings = netStaticOptimized.fireableBindings(for: transition, with: marking, factory: factory)
      var res: Set<Marking<PlaceType>> = [marking]
      
      for binding in allBindings {
        let bindingWithLabel = Dictionary(
          uniqueKeysWithValues: binding.map {
            (key, value) in
              (key.label, value)
          })
                
        res.insert(netStaticOptimized.fire(transition: transition, from: marking, with: bindingWithLabel)!)
      }
      
      return res
    }
    
    return []
  }
}


