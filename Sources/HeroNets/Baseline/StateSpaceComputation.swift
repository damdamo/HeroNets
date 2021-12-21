public struct Baseline<PlaceType, TransitionType>
where PlaceType: Place, PlaceType.Content == Multiset<Val>, TransitionType: Transition
{
  
  public typealias Var = String
//  public typealias Val = PlaceType.Content.Key

  var heroNet: HeroNet<PlaceType, TransitionType>
  
  public init(heroNet: HeroNet<PlaceType, TransitionType>) {
    self.heroNet = heroNet
  }
  
  // -------------------------- BRUTE FORCE OPTIMIZED NET -------------------------- //
  
  /// Compute bindings of a transition and a marking in a hero net with optimizations
  public func bindingBruteForceWithOptimizedNet(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> Set<[Var: Val]> {
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = heroNet.computeStaticOptimizedNet()
    
    if let (netWithoutConstant, newMarking) = staticOptimizedNet.consumeConstantOnArcs(transition: transition, marking: marking) {
      // From old name to new name
      let originalLabels = netWithoutConstant.createSetOfVariableLabel(transition: transition)
      let newNetWithUniqueLabel = setUniqueVariableForATransition(transition: transition, net: netWithoutConstant)
      
      return fireableBindingsBF(transition: transition, marking: newMarking, net: newNetWithUniqueLabel, originalLabels: originalLabels)
    }
    
    return []
  }
  
  /// Compute the state space of a hero net for a marking with optimizations
  public func CSSBruteForceWithOptimizedNet(marking: Marking<PlaceType>) -> Set<Marking<PlaceType>> {
    let staticOptimizedNet = heroNet.computeStaticOptimizedNet()
    return computeStateSpace(from: marking, net: staticOptimizedNet)
  }
  
  // -------------------------- BRUTE FORCE NON OPTIMIZED NET -------------------------- //
  
  /// Compute bindings of a transition and a marking in a hero net without optimization
  public func bindingBruteForce(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> Set<[Var: Val]> {
    
    if let (netWithoutConstant, newMarking) = self.heroNet.consumeConstantOnArcs(transition: transition, marking: marking) {
      // From old name to new name
      let originalLabels = netWithoutConstant.createSetOfVariableLabel(transition: transition)
      let newNetWithUniqueLabel = setUniqueVariableForATransition(transition: transition, net: netWithoutConstant)
      return fireableBindingsBF(transition: transition, marking: newMarking, net: newNetWithUniqueLabel, originalLabels: originalLabels)
    }
    return []
  }
  
  /// Compute the state space of a hero net for a marking without optimization
  public func CSSBruteForce(marking: Marking<PlaceType>) -> Set<Marking<PlaceType>> {
    return computeStateSpace(from: marking, net: self.heroNet)
  }
  
  // -------------------------- Computation functions -------------------------- //

  /// Compute the state space of a hero net for a marking
  func computeStateSpace(
    from m0: Marking<PlaceType>,
    net: HeroNet<PlaceType, TransitionType>
  ) -> Set<Marking<PlaceType>> {
    var markingToCheck: Set<Marking<PlaceType>> = [m0]
    var markingAlreadyChecked: Set<Marking<PlaceType>> = [m0]
    
    while !markingToCheck.isEmpty {
      for marking in markingToCheck {
        for transition in TransitionType.allCases {
          if let (newNet, newMarking) = net.consumeConstantOnArcs(transition: transition, marking: marking) {
            let markingsForAllBindings = fireForAllBindings(
              transition: transition,
              from: newMarking,
              net: newNet
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
    }
    
    return markingAlreadyChecked
    
  }
  
  /// Fire all possible bindings for a transition
  func fireForAllBindings(
    transition: TransitionType,
    from marking: Marking<PlaceType>,
    net: HeroNet<PlaceType, TransitionType>
  ) -> Set<Marking<PlaceType>> {
    
    let originalLabels = net.createSetOfVariableLabel(transition: transition)
    let allBindings = fireableBindingsBF(transition: transition, marking: marking, net: net, originalLabels: originalLabels)
    var res: Set<Marking<PlaceType>> = []
    for binding in allBindings {
      if let firingResult = net.fire(transition: transition, from: marking, with: binding) {
        res.insert(firingResult)
      }
    }

    return res
    
  }
  
  
  /// Return all fireable bindings for a transition in a brute force way
  func fireableBindingsBF(
    transition: TransitionType,
    marking: Marking<PlaceType>,
    net: HeroNet<PlaceType, TransitionType>,
    originalLabels: Set<Var>)
  -> Set<[Var: Val]> {
    
    var res: Set<[Var: Val]> = []
    var temp: Set<[Var: Val]> = []
    var labels: [Var] = []
    
    if let placeToValues = net.input[transition] {
      for (place, values) in placeToValues {
        for value in values {
          switch value {
          case .var(let v):
            labels.append(v)
          default:
            continue
          }
        }
//        labels = values
        
        // If there is no label, the empty solution is good
        if labels.isEmpty {
          temp = [[:]]
        } else {
          temp = computeBindingsForAPlaceBF(labels: labels, placeValues: marking[place])
        }
        
        if res.isEmpty {
          res = temp
        }
        
        res = res.map({(dic1) -> Set<[Var: Val]> in
          return Set(temp.map({(dic2) -> [Var: Val] in
            return dic1.merging(dic2, uniquingKeysWith: {(old, _) in old})
          }))
        }).reduce([], {(cur, new) in
          cur.union(new)
        })
        
        labels = []
      }
    }
    
    if let conditions = net.guards[transition] {
      for binding in res {
        if !net.checkGuards(conditions: conditions, with: binding) {
          res.remove(binding)
        }
      }
    }
    
    res = Set(res.map({(dic) -> [Var: Val] in
      var dicTemp = dic
      for (k,_) in dic {
        if !originalLabels.contains(k) {
          dicTemp.removeValue(forKey: k)
        }
      }
      return dicTemp
    }))
    
    return res
  }
  
  
  func computeBindingsForAPlaceBF(
    labels: [Var],
    placeValues: Multiset<Val>
  ) -> Set<[Var: Val]> {
    
    if labels.count == 0 {
      return []
    }
    
    var res: Set<[Var: Val]> = []
    var temp: Set<[Var: Val]> = []
    var values = placeValues
    
    if let firstLabel = labels.first {
      for value in values {
        values.remove(value, occurences: 1)
        temp = computeBindingsForAPlaceBF(labels: Array(labels.dropFirst()), placeValues: values)
        res.insert([firstLabel: value])
        
        if temp.isEmpty {
          for v in values {
            res.insert([firstLabel: v])
          }
          return res
        }
        
        res = res.map({(dic1) -> Set<[Var: Val]> in
          return Set(temp.map({(dic2) -> [Var: Val] in
            return dic1.merging(dic2, uniquingKeysWith: {(old, _) in old})
          }))
        }).reduce([], {(cur, new) in
          cur.union(new)
        })
        
        values = placeValues
        
      }
    }
    
    return res
  }
  
  func setUniqueVariableForATransition(transition: TransitionType, net: HeroNet<PlaceType, TransitionType>) -> HeroNet<PlaceType, TransitionType> {
    
    // ILang but only variables
    var dicCountLabel: [ILang: Int] = [:]
    let labelSet = heroNet.createSetOfVariableLabel(transition: transition)

    for label in labelSet {
      dicCountLabel[.var(label)] = 0
    }
    
    var newInput = net.input
    let newOutput = net.output
    var newGuards = net.guards

    if let pre = newInput[transition] {
      for (place, labels) in pre {
        for label in labels {
          switch label {
          case .var(let v):
            if dicCountLabel[label] != 0 {
              let newVar = ILang.var("\(v)_\(dicCountLabel[label]!)")
              newInput[transition]![place]!.remove(label)
              newInput[transition]![place]!.insert(newVar)
              if let _ = newGuards[transition] {
                newGuards[transition]!.append(Pair(label,newVar))
              } else {
                newGuards[transition] = [Pair(label,newVar)]
              }
              dicCountLabel[label]! += 1
            } else {
              dicCountLabel[label]! += 1
            }
          default:
            continue
          }
        }
      }
    }
    
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: net.interpreter)
    
  }
  
}
