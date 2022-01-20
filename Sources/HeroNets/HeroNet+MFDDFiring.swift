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
  func fireAllEnabledBindingsSimple(
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
  
  // ------------------------------------------------------------------------- //
  // ------------------------------------------------------------------------- //
  // ------------------------------------------------------------------------- //

  public func computeStateSpace(
    from m0: Marking<PlaceType>,
    markingMFDDFactory: MarkingMFDDFactory)
  -> MarkingMFDD {
    
    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }
    let bindingMFDDFactory = BindingMFDDFactory()
    let netStaticOptimized = computeStaticOptimizedNet()
    var res = m0.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
    var resTemp = res
    var resFixPoint = res
    var resTemp2 = res
    repeat {
      res = resFixPoint
      for m in resTemp2 {
        let marking = Marking<PlaceType>(m)
        let markingMFDD = marking.markingToMFDDMarking(markingMFDDFactory: markingMFDDFactory)
        resTemp = resTemp.union(netStaticOptimized.fireAllTransitionsHom(from: marking, markingMFDDFactory: markingMFDDFactory, bindingMFDDFactory: bindingMFDDFactory).apply(on: markingMFDD))
      }
      resTemp2 = resTemp
      resFixPoint = resFixPoint.union(resTemp)
      resTemp = markingMFDDFactory.zero
    } while res != resFixPoint
    return res
  }
  
  
  func fireAllTransitionsHom(
    from marking: Marking<PlaceType>,
    markingMFDDFactory: MarkingMFDDFactory,
    bindingMFDDFactory: BindingMFDDFactory)
  -> NaryUnion<NaryUnion<BinaryComposition<MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking, MFDD<KeyMarking, ValueMarking>.InsertMarking>>> {
    
    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }
    var transitionMorphisms: [NaryUnion<BinaryComposition<MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking, MFDD<KeyMarking, ValueMarking>.InsertMarking>>] = []
    for t in TransitionType.allCases {
      transitionMorphisms.append(fireAllBindingsHom(transition: t, from: marking, markingMFDDFactory: markingMFDDFactory, bindingMFDDFactory: bindingMFDDFactory))
    }
    
    return morphisms.union(of: transitionMorphisms)
  }
    

  func fireAllBindingsHom(
    transition: TransitionType,
    from marking: Marking<PlaceType>,
    markingMFDDFactory: MarkingMFDDFactory,
    bindingMFDDFactory: BindingMFDDFactory)
  -> NaryUnion<BinaryComposition<MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking, MFDD<KeyMarking, ValueMarking>.InsertMarking>> {

    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }
    var firingMorphisms: [BinaryComposition<MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking, MFDD<KeyMarking, ValueMarking>.InsertMarking>] = []
    for binding in fireableBindings(for: transition, with: marking, factory: bindingMFDDFactory, isStateSpaceComputation: true) {
      let bindingWithLabel = Dictionary(
        uniqueKeysWithValues: binding.map {
          (key, value) in
            (key.label, value)
        })
      firingMorphisms.append(
        fireHom(transition: transition, binding: bindingWithLabel, markingMFDDFactory: markingMFDDFactory))
    }
    return morphisms.union(of: firingMorphisms)
  }
  
  
  /// Fire a transition using MFDD. It transforms a marking into a MFDD, then compute a homorphism for pre and post arcs.
  /// Eventually, it computes the final result using a composition of both homorphism on the marking.
  /// - Parameters:
  ///   - transition: Transition to be fired
  ///   - marking: Current marking
  ///   - binding: The binding to use for the firing
  ///   - markingMFDDFactory: A factory that keeps in memory the operations
  /// - Returns: The homomorphism to compute the firing effect
  func fireHom(
    transition: TransitionType,
    binding: [Var: Val],
    markingMFDDFactory: MarkingMFDDFactory)
  -> BinaryComposition<MFDD<KeyMarking, ValueMarking>.ExclusiveFilterMarking, MFDD<KeyMarking, ValueMarking>.InsertMarking> {

    var morphisms: MarkingMFDDMorphismFactory { markingMFDDFactory.morphisms }
    
    var markingToFilter: [(key: KeyMarking, value: ValueMarking)] = []
    var markingToInsert: [(key: KeyMarking, value: ValueMarking)] = []
    
    for (p, values) in pre(binding: binding, transition: transition).sorted(by: {$0.key < $1.key}) {
      markingToFilter.append((key: p, value: values))
    }
    
    for (p, values) in post(binding: binding, transition: transition).sorted(by: {$0.key < $1.key}) {
      markingToInsert.append((key: p, value: values))
    }
    
    let preHomomorphism = morphisms.filterMarking(excluding: markingToFilter)
    let postHomomorphism = morphisms.insertMarking(insert: markingToInsert)
    let compositionHomomorphism = morphisms.composition(of: preHomomorphism, with: postHomomorphism)
    return compositionHomomorphism
  }
  
}


