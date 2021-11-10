import DDKit

extension HeroNet where PlaceType: Comparable {
  
  public typealias KeyMarking = PlaceType
  public typealias ValueMarking = Pair<PlaceType.Content.Key, Int>
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  public typealias MarkingMFDDMorphismFactory = MFDDMorphismFactory<KeyMarking, ValueMarking>
  
  public func fire(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [Label: Value], markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {
    
    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }

    let markingMFDD = marking.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
    let preHomomorphism = computePreHomomorphism(binding: binding, transition: transition, morphisms: morphisms)
    let postHomomorphism = computePostHomomorphism(binding: binding, transition: transition, morphisms: morphisms)
    
    let compositionHomomorphism = morphisms.composition(of: preHomomorphism, with: postHomomorphism)
    return compositionHomomorphism.apply(on: markingMFDD)
  }
  
  private func computePostHomomorphism(
    binding: [Label: Value],
    transition: TransitionType,
    morphisms: MarkingMFDDMorphismFactory)
  -> MFDD<KeyMarking, ValueMarking>.InsertValueInMarking
  {

    var elementsToAdd: [PlaceType: [Value: Int]] = [:]
    var elementsToAddWithPair: [(key: PlaceType, values: [ValueMarking])] = []
    
    var exprSubs: String = ""
    var valOutput: Value = ""
    if let post = output[transition] {
      for (place, expressions) in post {
        elementsToAdd[place] = [:]
        for expr in expressions {
          exprSubs = bindingSubstitution(expr: expr, binding: binding)
          let context = interpreter.saveContext()
          valOutput = "\(try! interpreter.eval(string: exprSubs))"
          interpreter.reloadContext(context: context)
          if let _ = elementsToAdd[place]![valOutput] {
            elementsToAdd[place]![valOutput]! += 1
          } else {
            elementsToAdd[place]![valOutput] = 1
          }
          
        }
        
      }
      
      for (key, values) in elementsToAdd {
        elementsToAddWithPair.append(
          (
            key: key,
            values: values.map({(value, occurence) in
              return Pair(value, occurence)
            })
          )
        )
      }
      
    }
    
    return morphisms.insertValueInMarking(
      insert: elementsToAddWithPair
    )

  }
  
  
  private func computePreHomomorphism(
    binding: [Label: Value],
    transition: TransitionType,
    morphisms: MarkingMFDDMorphismFactory)
  -> MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking
  {
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
    }
    return morphisms.filterMarking(excluding: elementsToFilter)
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


