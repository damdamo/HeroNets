import DDKit

extension HeroNet where PlaceType: Comparable {
  
  public typealias KeyMarking = PlaceType
  public typealias ValueMarking = PlaceType.Content
  public typealias MarkingMFDD = MFDD<KeyMarking,ValueMarking>
  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
  public typealias MarkingMFDDMorphismFactory = MFDDMorphismFactory<KeyMarking, ValueMarking>
  
  
  /// Compute the state space of a net from a given marking in a brute force (BF) way.
  /// The enabled bindings are computed using our method with MFDD
  /// - Parameters:
  ///   - from m0: From the initial marking
  /// - Returns:
  ///   Returns the whole state space, i.e. all states that are reachable from an initial marking
  public func computeStateSpaceBF(from m0: Marking<PlaceType>)
  -> Set<Marking<PlaceType>> {
    
    var markingToCheck: Set<Marking<PlaceType>> = [m0]
    var markingAlreadyChecked: Set<Marking<PlaceType>> = [m0]
    let netStaticOptimized = computeStaticOptimizedNet()
    let heroMFDDFactory = BindingMFDDFactory()
    
    while !markingToCheck.isEmpty {
      for marking in markingToCheck {
        for transition in TransitionType.allCases {
          let markingsForAllBindings = netStaticOptimized.fireAllEnabledBindingsSimple(
            transition: transition,
            from: marking,
            heroMFDDFactory: heroMFDDFactory
          )
          for newMarking in markingsForAllBindings {
            if !markingAlreadyChecked.contains(newMarking) {
              markingToCheck.insert(newMarking)
              markingAlreadyChecked.insert(newMarking)
            }
          }
        }
        markingToCheck.remove(marking)
      }
    }
    
    return markingAlreadyChecked
    
  }
  
  /// Fire all bindings for a given transition and a given marking. The simple version uses a set of marking, and not a MFDD.
  private func fireAllEnabledBindingsSimple(
    transition: TransitionType,
    from marking: Marking<PlaceType>,
    heroMFDDFactory: BindingMFDDFactory
  )
  -> Set<Marking<PlaceType>> {
            
    let allBindings = fireableBindings(for: transition, with: marking, factory: heroMFDDFactory, isStateSpaceComputation: true)
    var res: Set<Marking<PlaceType>> = []
    for binding in allBindings {
      let bindingWithLabel = Dictionary(
        uniqueKeysWithValues: binding.map {
          (key, value) in
            (key.label, value)
        })
      if let r = fire(transition: transition, from: marking, with: bindingWithLabel, isStateSpaceComputation: true) {
        res.insert(r)
      }
    }

    return res
  }
  
  //  public func computeStateSpace(
  //    from m0: Marking<PlaceType>,
  //    markingMFDDFactory: MarkingMFDDFactory)
  //  -> Set<MarkingMFDD> {
  //
  //    let m0MFDD = m0.markingToMFDD(markingMFDDFactory: markingMFDDFactory)
  //    let heroMFDDFactory = HeroMFDDFactory()
  //    var markingToCheck: Set<MarkingMFDD> = [m0MFDD]
  //    var markingAlreadyChecked: Set<MarkingMFDD> = [m0MFDD]
  //    let netStaticOptimized = computeStaticOptimizedNet()
  //
  //    while !markingToCheck.isEmpty {
  //      for marking in markingToCheck {
  //        for transition in TransitionType.allCases {
  //          let markingsForAllBindings = netStaticOptimized.fireForAllBindings(
  //            transition: transition,
  //            from: m0.mfddToMarking(markingMFDD: marking, markingMFDDFactory: markingMFDDFactory),
  //            markingMFDDFactory: markingMFDDFactory, heroMFDDFactory: heroMFDDFactory)
  //
  //          for newMarking in markingsForAllBindings {
  //            if !markingAlreadyChecked.contains(newMarking) {
  //              markingToCheck.insert(newMarking)
  //              markingAlreadyChecked.insert(newMarking)
  //            }
  //          }
  //        }
  //        markingToCheck.remove(marking)
  //      }
  //    }
  //
  //    return markingAlreadyChecked
  //
  //  }
  
//  private func fireForAllBindings(
//    transition: TransitionType,
//    from marking: Marking<PlaceType>,
//    markingMFDDFactory: MarkingMFDDFactory,
//    heroMFDDFactory: HeroMFDDFactory
//  )
//  -> Set<MarkingMFDD> {
//
//    let allBindings = self.fireableBindingsForCSS(for: transition, with: marking, factory: heroMFDDFactory)
//    var res: Set<MarkingMFDD> = []
//    for binding in allBindings {
//      let bindingWithLabel = Dictionary(
//        uniqueKeysWithValues: binding.map {
//          (key, value) in
//            (key.label, value)
//        })
//      res.insert(self.fire(transition: transition, from: marking, with: bindingWithLabel, markingMFDDFactory: markingMFDDFactory))
//    }
//
//    return res
//  }
  
  /// Fire a transition using MFDD. It transforms a marking into a MFDD, then compute a homorphism for pre and post arcs.
  /// Eventually, it computes the final result using a composition of both homorphism on the marking.
  /// - Parameters:
  ///   - transition: Transition to be fired
  ///   - marking: Current marking
  ///   - binding: The binding to use for the firing
  ///   - markingMFDDFactory: A factory that keeps in memory the operations
  /// - Returns: The new marking as a MFDD
  func fire(transition: TransitionType, markingMFDD: MarkingMFDD, binding: [Var: Val], markingMFDDFactory: MarkingMFDDFactory) -> MarkingMFDD {

    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }
    
    var markingToFilter: [(key: KeyMarking, value: ValueMarking)] = []
    var markingToInsert: [(key: KeyMarking, value: ValueMarking)] = []
    var marking: ValueMarking = []
    
    if let i = input[transition] {
      for (p, vars) in i.sorted(by: {$0.key < $1.key}) {
        for v in vars {
          switch v {
          case .var(let name):
            marking.insert(binding[name]!)
          default:
            continue
          }
        }
        markingToFilter.append((key: p, value: marking))
        marking = []
      }
    }
    
    if let o = output[transition] {
      for (p, vars) in o.sorted(by: {$0.key < $1.key}) {
        for v in vars {
          marking.insert(eval(bindVariables(expr: v, binding: binding)))
        }
        markingToInsert.append((key: p, value: marking))
        marking = []
      }
    }
    
    let preHomomorphism = morphisms.filterMarking(excluding: markingToFilter)
    let postHomomorphism = morphisms.insertMarking(insert: markingToInsert)
    let compositionHomomorphism = morphisms.composition(of: preHomomorphism, with: postHomomorphism)
    return compositionHomomorphism.apply(on: markingMFDD)
  }
  
  
  /// Compute the homomorphism for post arcs. It transforms the binding into a specific format to create the homorphism.
//  private func computePostHomomorphism(
//    binding: [Label: Value],
//    transition: TransitionType,
//    morphisms: MarkingMFDDMorphismFactory)
//  -> MFDD<KeyMarking, ValueMarking>.InsertValueInMarking
//  {
//
//    var elementsToAdd: [PlaceType: [Value: Int]] = [:]
//    var elementsToAddWithPair: [(key: PlaceType, values: [ValueMarking])] = []
//
//    var exprSubs: String = ""
//    var valOutput: Value = ""
//    if let post = output[transition] {
//      for (place, expressions) in post {
//        elementsToAdd[place] = [:]
//        for expr in expressions {
//          exprSubs = bindVariables(expr: expr, binding: binding)
//          valOutput = eval(exprSubs)
//          if let _ = elementsToAdd[place]![valOutput] {
//            elementsToAdd[place]![valOutput]! += 1
//          } else {
//            elementsToAdd[place]![valOutput] = 1
//          }
//
//        }
//
//      }
//
//      for (key, values) in elementsToAdd {
//        elementsToAddWithPair.append(
//          (
//            key: key,
//            values: values.map({(value, occurence) in
//              return Pair(value, occurence)
//            })
//          )
//        )
//      }
//
//    }
//
//    return morphisms.insertValueInMarking(
//      insert: elementsToAddWithPair
//    )
//
//  }
  
  /// Compute the homomorphism for pre arcs. It transforms the binding into a specific format to create the homorphism.
//  private func computePreHomomorphism(
//    binding: [Label: Value],
//    transition: TransitionType,
//    morphisms: MarkingMFDDMorphismFactory)
//  -> MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking
//  {
//    var elementsToFilter: [(key: PlaceType, values: [ValueMarking])] = []
//    
//    if let pre = input[transition] {
//      for (place, labels) in pre {
//        
//        // Get the list of values using list of variables for each place
//        let listeValues = labels.map({(label) -> Value in
//          if let val = binding[label] {
//            return val
//          }
//          return label
//        })
// 
//        // Using the listValues, we transform it into a dictionnary that
//        let dicValues = listeValues.reduce([:], {(currentDic, newValue) -> [Value: Int] in
//          var dicTemp = currentDic
//          if let _ = currentDic[newValue] {
//            dicTemp[newValue]! += 1
//          } else {
//            dicTemp[newValue] = 1
//          }
//          
//          return dicTemp
//        })
//        
//        elementsToFilter.append((
//          key: place,
//          values: dicValues.map({(value, occurence) in
//            Pair(value, occurence)
//          })
//        ))
//        
//      }
//    }
//    return morphisms.filterMarking(excluding: elementsToFilter)
//  }
  
//  public func generateAllFiring(for transition: TransitionType, with marking: Marking<PlaceType>)
//  -> Set<Marking<PlaceType>>
//  {
//
//    let factory = HeroMFDDFactory()
//    let netStaticOptimized = computeStaticOptimizedNet(transition: transition)
//
//    if let netStaticOptimized = netStaticOptimized {
//      let allBindings = netStaticOptimized.fireableBindings(for: transition, with: marking, factory: factory)
//      var res: Set<Marking<PlaceType>> = [marking]
//
//      for binding in allBindings {
//        let bindingWithLabel = Dictionary(
//          uniqueKeysWithValues: binding.map {
//            (key, value) in
//              (key.label, value)
//          })
//
//        res.insert(netStaticOptimized.fire(transition: transition, from: marking, with: bindingWithLabel)!)
//      }
//
//      return res
//    }
//
//    return []
//  }
}


