import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  public typealias KeyMFDD = Key<Label>
  public typealias HeroMFDD = MFDD<KeyMFDD,Value>
  public typealias HeroMFDDFactory = MFDDFactory<KeyMFDD,Value>
  
  /// Creates the fireable bindings of a transition.
  ///
  /// - Parameters:
  ///   - transition: The transition for which we want to compute all bindings
  ///   - marking: The marking which is the initial state of the net
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   The MFDD which represents all fireable bindings.
  func fireableBindings(
    for transition: TransitionType,
    with marking: Marking<PlaceType>,
    factory: HeroMFDDFactory
  ) -> HeroMFDD {
    
    let (arcLabels, listCondition) = optimizationEqualityGuard(transition: transition)
    
//    print("New input: \(arcLabels)")
//    print("List condition: \(listCondition)")
    
    // All variables imply in the transition firing keeping the group by arc
    var labelSet: Set<Label> = []
    
    // placeToExprs: Expressions contain in a place
    // placeToVars: Vars related to a place
    var placeToExprs: [PlaceType: Multiset<Value>] = [:]
    var placeToLabels: [PlaceType: Multiset<Label>] = [:]
    
    var varMultiset: Multiset<Label> = []
    // Preprocess the net, removing constant on the arc and consuming the value in the corresponding place
    // and creates the list of variables
    for (place, labels) in arcLabels {
      placeToExprs[place] = marking[place]
      for lab in labels {
        if !lab.contains("$") {
          if placeToExprs[place]!.contains(lab) {
            // Remove one occurence
            placeToExprs[place]!.remove(lab)
          } else {
            return factory.zero
          }
        } else {
          varMultiset.insert(lab)
          labelSet.insert(lab)
        }
      }
      placeToLabels[place] = varMultiset
      varMultiset = []
    }
    
    // Get all the possibilities for each labels
    var labelToExprs = associateLabelToExprsForPlace(placeToExprs: placeToExprs, arcLabels: arcLabels)
    
    // Isolate condition with a unique variable
    let (condWithUniqueLab, condRest) = isolateCondWithUniqueLabel(labelSet: labelSet, conditions: listCondition)

    // Check for condition with a unique label and simplify the range of possibility for the corresponding label
    // E.g.: Suppose the guard: (x,1), x can be only 1.
    labelToExprs = constantPropagation(labelToExprs: labelToExprs, conditionsWithUniqueLabel: condWithUniqueLab)
        
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: condRest
    )
        
    // Return the sorted key to expressions list
    let keyToExprs = computeKeyToExprs(
      labelSet: labelSet,
      labelWeights: labelWeights,
      labelToExprs: labelToExprs
    )
    
    // Construct the mfdd
    var mfddPointer = constructMFDD(
      keyToExprs: keyToExprs,
      arcLabels: arcLabels,
      factory: factory,
      placeToExprs: placeToExprs,
      placeToLabels: placeToLabels
    )
    
    
    if condRest != []  {
      var keySet: Set<KeyMFDD> = []

      for (key, _) in keyToExprs {
        keySet.insert(key)
      }
        
      for condition in condRest.sorted(by: {conditionWeights![$0]! > conditionWeights![$1]!}) {
        // Apply guards
        mfddPointer = applyCondition(
          mfddPointer: mfddPointer,
          condition: condition,
          keySet: keySet,
          factory: factory
        )
      }
    }
    
    return MFDD(pointer: mfddPointer, factory: factory)
        
  }
  
  func optimizationEqualityGuard(transition: TransitionType) -> ([PlaceType: [Label]], [Pair<Value>]) {
    
    guard let _ = guards[transition] else { return (input[transition]!, [])}
    
    var labelList: Set<Label> = []
    var newInput = input[transition]!
    
    if let pre = input[transition] {
      for (_, labels) in pre {
        for label in labels {
          labelList.insert(label)
        }
      }
    }
    
    var eqLabelList: [Pair<Label>] = []
    var conditionList: [Pair<Value>] = []
    
    if let conditions = guards[transition] {
      for condition in conditions {
        if labelList.contains(condition.l) && labelList.contains(condition.r) {
          eqLabelList.append(Pair(condition.l, condition.r))
        } else {
          conditionList.append(condition)
        }
      }
    }
        
    while eqLabelList != [] {
      let pair = eqLabelList.first!
      eqLabelList.removeFirst()
            
      for i in 0 ..< conditionList.count {
        if conditionList[i].l.contains(pair.l) {
          conditionList[i].l = conditionList[i].l.replacingOccurrences(of: pair.l, with: pair.r)
        }
        if conditionList[i].r.contains(pair.l) {
          conditionList[i].r = conditionList[i].r.replacingOccurrences(of: pair.l, with: pair.r)
        }
      }
      
      for i in 0 ..< eqLabelList.count {
        if eqLabelList[i].l == pair.l {
          eqLabelList[i].l = pair.r
        }
        if eqLabelList[i].r == pair.l {
          eqLabelList[i].r = pair.r
        }
      }
      
      for (place, labels) in newInput {
        
        newInput[place] = labels.map({(lab) in
          if lab == pair.l {
            return pair.r
          }
          return lab
        })
      }
      
    }

    return (newInput, conditionList)
  }
  
  func constantPropagation(labelToExprs: [Label: Multiset<Value>], conditionsWithUniqueLabel: [Label: [Pair<Value>]]) -> [Label: Multiset<Value>] {
    
    var labelToExprsTemp = labelToExprs
    
    // Need to create the interpreter here for performance
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    for (labCond, condRest) in conditionsWithUniqueLabel {
      for expr in labelToExprs[labCond]! {
        for cond in condRest {
          if !checkGuards(condition: cond, with: [labCond: expr], interpreter: interpreter) {
            labelToExprsTemp[labCond]!.removeAll(expr)
          }
        }
      }
    }
    
    return labelToExprsTemp
  }
  
  /// Create a new mfdd pointer from the current mfdd where we filter values which does not satisfy the condition
  /// - Parameters:
  ///   - mfddPointer: The complete mfdd pointer without any guards.
  ///   - condition: The condition the mfdd has to satisfy
  ///   - keySet: The list of all keys imply in the transition
  ///   - factory: The mfdd factory
  /// - Returns:
  ///   Returns the new mfdd that have applied the condition.
  func applyCondition(
    mfddPointer: HeroMFDD.Pointer,
    condition: Pair<Value>,
    keySet: Set<KeyMFDD>,
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    var morphisms: MFDDMorphismFactory<KeyMFDD, Value> { factory.morphisms }
    let keyCond = keySet.filter({(key) in
      if condition.l.contains(key.label) || condition.r.contains(key.label) {
        return true
      }
      return false
    })
        
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let morphism = guardFilter(condition: condition, keyCond: Array(keyCond), factory: factory, heroNet: self, interpreter: interpreter)
    
    return morphism.apply(on: mfddPointer)
    
  }
  
  
  /// Isolate conditions with a unique variable to apply the constant propagation
  /// - Parameters:
  ///   - LabelSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  func isolateCondWithUniqueLabel(labelSet: Set<Label>, conditions: [Pair<Value>]?) -> ([Label: [Pair<Value>]], [Pair<Value>]) {

    var labelSetTemp: Set<Label> = []
    var condWithUniqueVariable: [Label: [Pair<Value>]] = [:]
    var restConditions: [Pair<Value>] = []

    if let conds = conditions {
      for cond in conds {
        for label in labelSet {
          if cond.l.contains(label) || cond.r.contains(label) {
            labelSetTemp.insert(label)
          }
        }
        // Check that we have the same variable, and one of both side contains just this variable
        if labelSetTemp.count == 1 {
          if let _ = condWithUniqueVariable[labelSetTemp.first!] {
            condWithUniqueVariable[labelSetTemp.first!]!.append(cond)
          } else {
            condWithUniqueVariable[labelSetTemp.first!] = [cond]
          }
        } else {
          restConditions.append(cond)
        }
        labelSetTemp = []
      }
    }
    return (condWithUniqueVariable, restConditions)

  }
  
  /// Creates a MFDD pointer that represents all possibilities for a transition without guards.
  /// A MFDD pointer is computed for each place before being merge with a specific homomorphism.
  ///
  /// - Parameters:
  ///   - keyToExprs: A dictionnary that binds a key to its possible expressions
  ///   - transition: The transition that we're looking at.
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args.
  func constructMFDD(
    keyToExprs: [KeyMFDD: Multiset<Value>],
    arcLabels: [PlaceType: [Label]],
    factory: HeroMFDDFactory,
    placeToExprs: [PlaceType: Multiset<Value>],
    placeToLabels: [PlaceType: Multiset<Label>]
  ) -> HeroMFDD.Pointer {

    var keyToExprsForAPlace: [KeyMFDD: Multiset<Value>] =  [:]
    var labelToKey: [Label: KeyMFDD] = [:]
    
    for (key, _) in keyToExprs {
      labelToKey[key.label] = key
    }
          
    var cache: [[HeroMFDD.Pointer]: HeroMFDD.Pointer] = [:]
    var mfddPointer = factory.zero.pointer
    
    for (place, labels) in arcLabels {
      keyToExprsForAPlace = computeExprsForALabelOfAPlace(
        place: place,
        labels: labels,
        labelToKey: labelToKey,
        keyToExprs: keyToExprs,
        placeToExprs: placeToExprs)

      let mfddTemp = constructMFDD(keyToExprs: keyToExprsForAPlace, factory: factory)
      
      // Apply the homomorphism
      mfddPointer = factory.concatAndFilterInclude(
        mfddPointer,
        mfddTemp,
        cache: &cache,
        factory: factory
      )
      keyToExprsForAPlace = [:]
    }

    return mfddPointer
    
  }
  
  /// Creates a dictionnary of key to multiset of expressions for a specific place
  /// Therefore, we get each possible values for a key.
  /// In addition, there is another trick here. Earlier in the process, we do an intersection to keep only possible values for a same variable.
  /// It could be a problem when there is no the same amount of a same value in two places (either it is more or less).
  /// Let suppose: P1 -(x,y)-> T1, P2 -(x)-> T1, with P1: {"1", "1", "2"}, P2: {"1"}
  /// When we do the first intersection at the beginning of the process, we get "x": {"1"}, even though "x" appears two times in P1
  /// If we try to create the MFDD with this information, we can have a scenario where "y" is at the top of the MFDD and takes "1".
  /// So, "x" cannot select "1" again if we do not know there is two "1" in P1.
  /// The same logic is applicable in the other way, if we try to take the upperbound directly, cause we could suppose that a place has more a value than it is supposed to be.
  /// Therefore, the intersection upperbound is called only at the time we want to have the correct number of values for a place and a label.
  /// - Parameters:
  ///   - place: The current place
  ///   - labels: List of labels of the place,
  ///   - labelToKey: Associates each label to its own key
  ///   - keyToExprs. Associates each key to its possible expressions
  ///   - placeToExprs: Original values available in a place
  /// - Returns:
  ///   The real number of expressions for each label of a place
  func computeExprsForALabelOfAPlace(
    place: PlaceType,
    labels: [Label],
    labelToKey: [Label: KeyMFDD],
    keyToExprs: [KeyMFDD: Multiset<Value>],
    placeToExprs: [PlaceType: Multiset<Value>])
  -> [KeyMFDD: Multiset<Value>] {
    
    var keyToExprsForAPlace: [KeyMFDD: Multiset<Value>] =  [:]

    for label in labels {
      keyToExprsForAPlace[labelToKey[label]!] = keyToExprs[labelToKey[label]!]!.intersectionUpperBound(placeToExprs[place]!)
    }
    return keyToExprsForAPlace
  }
  
  /// Creates a MFDD pointer that represents all possibilities for a place without guards
  /// The MFDD is specific for a place.
  ///
  /// - Parameters:
  ///   - keyToExprs: A dictionnary that binds a key to its possible expressions, where keyToExprs contains only key for the given pre arc of a transition
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args for a place.
  func constructMFDD(
    keyToExprs: [KeyMFDD: Multiset<Value>],
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key,multiset) = keyToExprs.sorted(by: {$0 < $1}).first {
      var take: [Value: HeroMFDD.Pointer] = [:]
      var keyToExprsFirstDrop = keyToExprs
//      print("COUPABLE KEY: \(key)")
      keyToExprsFirstDrop.removeValue(forKey: key)
      
      for el in multiset {
        take[el] = constructMFDD(
          keyToExprs: keyToExprsFirstDrop.reduce(into: [:], {(res, couple) in
            var coupleTemp = couple
            coupleTemp.value.remove(el, occurences: 1)
            res[couple.key] = coupleTemp.value
          }),
          factory: factory
        )
      }
      return factory.node(key: key, take: take, skip: factory.zero.pointer)
    }
    return factory.zero.pointer
  }

  
  /// Create a label for each variable and associates the possible expressions. If the same variable appears multiple times, an intersection is made between multisets to keep only possible values. e.g.: ["1": 2, "2": 1, "4": 1] ∩ ["1": 1, "2": 1, "3": 1] = ["1": 1, "2": 1].
  /// Hence, if two places have different values, a variable that appears in precondition arcs of both can only take a value in the intersection.
  ///
  /// - Parameters:
  ///   - placeToExprs: Marking of each place (that has been modified earlier)
  ///   - transition: The transition for which we want to compute all bindings
  /// - Returns:
  ///   A dictionnary that associates each label to their expressions
  func associateLabelToExprsForPlace(
    placeToExprs: [PlaceType: Multiset<Value>],
    arcLabels: [PlaceType: [Label]])
  -> [Label: Multiset<Value>] {
    
    var labelToExprs: [Label: Multiset<Value>] = [:]
    for (place, labels) in arcLabels {
      for label in labels {
        if let _ = labelToExprs[label] {
          labelToExprs[label] = labelToExprs[label]!.intersection(placeToExprs[place]!)
        } else {
          labelToExprs[label] = placeToExprs[place]!
        }
      }
    }
    return labelToExprs
    
  }
  
  /// Compute a score for each variable using the guards, and the score of priority for each conditions. The score is used to determine the order to apply conditions
  ///
  /// - Parameters:
  ///   - labelSet: Set of labels
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a tuple with its first element a dictionnary that binds a label to its weight and second element a dictionnary that binds condition to a score !
  func computeScoreOrder(
    labelSet: Set<Label>,
    conditions: [Pair<Value>]?)
  -> ([Label: Int]?, [Pair<Value>: Int]?) {
    
    // If there is no conditions
    guard let _ = conditions else {
      return (nil, nil)
    }
    var labelWeights: [Label: Int] = [:]
    var conditionWeights: [Pair<Value>: Int] = [:]
    var labelForCond: [Set<Label>] = []
    var labelInACond: Set<Label> = []
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment its n value, allowing to distingue them
    for label in labelSet {
      labelWeights[label] = 100
    }
    
    for condition in conditions! {
      conditionWeights[condition] = 100
    }
    
    // To know condition variables
    for condition in conditions! {
      for label in labelSet {
        if condition.l.contains(label) || condition.r.contains(label) {
          labelInACond.insert(label)
        }
      }
      
      // Compute condition weights
      if labelInACond.count != 0 {
        conditionWeights[condition]! *= 2/labelInACond.count
      } else {
        conditionWeights[condition]! = 0
      }
      
      labelForCond.append(labelInACond)
      labelInACond = []
    }
    
    // To compute a score
    // If a condition contains the same variable, it earns 50 points
    // If a condition contains a variable with other variables, every variables earn 10 points
    for (label, _) in labelWeights {
      for cond in labelForCond {
        if cond.contains(label) {
          if cond.count == 1  {
            labelWeights[label]! += 100
          } else {
            labelWeights[label]! += 10
          }
        }
      }
    }
    
    return (labelWeights, conditionWeights)
  }
 
  /// Return the array of all possibles values for each labels that are transformed into keys. MFDD requires to have a total order relation between variables, so we construct this order using the weight computed before. We transform the precedent array of labels with expressions into an array of keys related to their multiset of expressions. This result is ordered using label weights.
  ///
  /// - Parameters:
  ///   - labelSet: The set of labels
  ///   - labelWeights: The weight of labels
  ///   - labelToExprs: A dictionnary of label binds to their possible expressions
  /// - Returns:
  ///   A sorted array that binds each key to their expressions, grouped by places and sorted using label weights
  func computeKeyToExprs(
    labelSet: Set<Label>,
    labelWeights: [Label: Int]?,
    labelToExprs: [Label: Multiset<Value>]
  ) -> [KeyMFDD: Multiset<Value>] {

    let totalOrder: [Pair<Label>]
    var keyToExprs: [KeyMFDD: Multiset<Value>] = [:]
    
    if let lw = labelWeights {
      totalOrder = createTotalOrder(labels: labelSet.sorted(by: {(label1, label2) -> Bool in
        lw[label1]! > lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(labels: Array(labelSet))
    }
    
    for (label,exprs) in labelToExprs {
      keyToExprs[KeyMFDD(label: label, couple: totalOrder)] = exprs
    }

    return keyToExprs
  }

  // createOrder creates a list of pair from a list of string
  // to represent a total order relation. Pair(l,r) => l < r
  func createTotalOrder(labels: [Label]) -> [Pair<Label>] {
      var r: [Pair<Label>] = []
      for i in 0 ..< labels.count {
        for j in i+1 ..< labels.count {
          r.append(Pair(labels[i],labels[j]))
        }
      }
      return r
  }
  
}
