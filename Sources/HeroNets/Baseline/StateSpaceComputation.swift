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
  
  func fireableBindingsBF(
    net: HeroNet<PlaceType, TransitionType>,
    placeToLabelToValues: [PlaceType : [Label : Multiset<Value>]])
  -> Set<[Label: Value]> {
    
    var res: Set<[Label: Value]> = []
    
    for (place, labelToValues) in placeToLabelToValues {
      res = computeBindingsForAPlaceBF(net: net, labelToValues: labelToValues)
    }
    
    return res
  }
  
  func computeBindingsForAPlaceBF(
    net: HeroNet<PlaceType, TransitionType>,
    labelToValues: [Label : Multiset<Value>]
  ) -> Set<[Label: Value]> {
    
    return []
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
              let newName = "\(label)_\(dicCountLabel[label])"
              newInput[transition]![place]!.append(newName)
              newGuards[transition]?.append(Pair(label,newName))
            }
          } else {
            dicCountLabel[label]! += 1
          }
        }
      }
    }
    
    if let post = newOutput[transition] {
      for (place, labels) in post {
        for label in labels {
          if dicCountLabel[label] != 0 {
            if let index = newOutput[transition]![place]?.firstIndex(of: label) {
              newOutput[transition]![place]!.remove(at: index)
              let newName = "\(label)_\(dicCountLabel[label])"
              newOutput[transition]![place]!.append(newName)
              newGuards[transition]?.append(Pair(label,newName))
            }
          } else {
            dicCountLabel[label]! += 1
          }
        }
      }
    }
    
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: net.interpreter)
    
  }
  
  func BindingBruteForceWithOptimizedNet(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> Set<[Label: Value]> {
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = heroNet.computeStaticOptimizedNet()
    
    // Dynamic optimization, depends on the structure of the net and the marking
    let dynamicOptimizedNet = staticOptimizedNet.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    
    if let (dynamicOptimizedNet, placeToLabelToValues) = dynamicOptimizedNet {
      
      let labelSet = heroNet.createLabelSet(transition: transition)
      // From old name to new name
      var dicCountLabel: [Label: Int] = [:]
      
      
//      replaceLabelsForATransition
      
      return fireableBindingsBF(net: dynamicOptimizedNet,placeToLabelToValues: placeToLabelToValues)
    }
    
    return []
  }
  
  func CSSBruteForceWithOptimizedNet() {
    
  }
  
  func BindingBruteForce() {
    
  }
  
  func CSSBruteForce() {
    
  }
  
//  func computeAllBindings() -> Set<Marking<Pla>> {}
  
}
