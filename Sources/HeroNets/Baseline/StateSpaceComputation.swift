public struct Baseline<PlaceType, TransitionType>
where PlaceType: Place, PlaceType.Content == Multiset<String>, TransitionType: Transition
{
  
  typealias Label = String
  typealias Value = PlaceType.Content.Key

  let heroNet: HeroNet<PlaceType, TransitionType>
  
//  func optimizedNet() -> HeroNet<PlaceType, TransitionType> {
//    var optimizedNet = heroNet.computeStaticOptimizedNet()
//    
//  }
  
  
  func bindingBruteForceWithOptimizedNet(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> Set<[Label: Value]> {
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = heroNet.computeStaticOptimizedNet()
    
    // Dynamic optimization, depends on the structure of the net and the marking
//    let dynamicOptimizedNet = staticOptimizedNet.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    
    if let (netWithoutConstant, newMarking) = staticOptimizedNet.removeConstantOnArcs(transition: transition, marking: marking) {
      
      // From old name to new name
      let originalLabels = netWithoutConstant.createLabelSet(transition: transition)
      let newNetWithUniqueLabel = setUniqueVariableForATransition(transition: transition, net: netWithoutConstant)
      return fireableBindingsBF(transition: transition, marking: newMarking, net: newNetWithUniqueLabel, originalLabels: originalLabels)
    }
    
    return []
  }
  
  func CSSBruteForceWithOptimizedNet() {
    
  }
  
  func BindingBruteForce() {
    
  }
  
  func CSSBruteForce() {
    
  }
  
  // Return all fireable bindings for a transition in a brute force way
  func fireableBindingsBF(
    transition: TransitionType,
    marking: Marking<PlaceType>,
    net: HeroNet<PlaceType, TransitionType>,
    originalLabels: Set<Label>)
  -> Set<[Label: Value]> {
    
    var res: Set<[Label: Value]> = []
    var temp: Set<[Label: Value]> = []
    var labels: [Label] = []
    
    if let placeToValues = net.input[transition] {
      for (place, values) in placeToValues {
        labels = values
        temp = computeBindingsForAPlaceBF(labels: labels, placeValues: marking[place])
        
        if res.isEmpty {
          res = temp
        }
        
        res = res.map({(dic1) -> Set<[Label: Value]> in
          return Set(temp.map({(dic2) -> [Label: Value] in
            return dic1.merging(dic2, uniquingKeysWith: {(old, _) in old})
          }))
        }).reduce([], {(cur, new) in
          cur.union(new)
        })
      }
    }
    
    if let conditions = net.guards[transition] {
      for binding in res {
        if !net.checkGuards(conditions: conditions, with: binding) {
          res.remove(binding)
        }
      }
    }
    
    res = Set(res.map({(dic) -> [Label: Value] in
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
    labels: [Label],
    placeValues: Multiset<Value>
  ) -> Set<[Label: Value]> {
    
    if labels.count == 0 {
      return []
    }
    
    var res: Set<[Label: Value]> = []
    var temp: Set<[Label: Value]> = []
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
        
        res = res.map({(dic1) -> Set<[Label: Value]> in
          return Set(temp.map({(dic2) -> [Label: Value] in
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
    
    var dicCountLabel: [Label: Int] = [:]
    let labelSet = heroNet.createLabelSet(transition: transition)

    for label in labelSet {
      dicCountLabel[label] = 0
    }
    
    var newInput = net.input
    var newOutput = net.output
    var newGuards = net.guards
    
    if let pre = newInput[transition] {
      for (place, labels) in pre {
        for label in labels {
          if dicCountLabel[label] != 0 {
            if let index = newInput[transition]![place]?.firstIndex(of: label) {
              newInput[transition]![place]!.remove(at: index)
              let newName = "\(label)_\(dicCountLabel[label]!)"
              newInput[transition]![place]!.append(newName)
              if let _ = newGuards[transition] {
                newGuards[transition]!.append(Pair(label,newName))
              } else {
                newGuards[transition] = [Pair(label,newName)]
              }
              dicCountLabel[label]! += 1
            }
          } else {
            dicCountLabel[label]! += 1
          }
        }
      }
    }
    
//    if let post = newOutput[transition] {
//      for (place, labels) in post {
//        for label in labels {
//          if dicCountLabel[label] != 0 {
//            if let index = newOutput[transition]![place]?.firstIndex(of: label) {
//              newOutput[transition]![place]!.remove(at: index)
//              let newName = "\(label)_\(dicCountLabel[label]!)"
//              newOutput[transition]![place]!.append(newName)
//              if let _ = newGuards[transition] {
//                newGuards[transition]!.append(Pair(label,newName))
//              } else {
//                newGuards[transition] = [Pair(label,newName)]
//              }
//              dicCountLabel[label]! += 1
//            }
//          } else {
//            dicCountLabel[label]! += 1
//          }
//        }
//      }
//    }
    
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: net.interpreter)
    
  }
  
//  func computeAllBindings() -> Set<Marking<Pla>> {}
  
}
