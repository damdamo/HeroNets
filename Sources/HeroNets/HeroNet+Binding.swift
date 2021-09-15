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
    
    // All variables imply in the transition firing keeping the group by arc
    var labelSet: Set<Label> = []
    
    // placeToExprs: Expressions contain in a place
    // placeToVars: Vars related to a place
    var placeToExprs: [PlaceType: Multiset<Value>] = [:]
    var placeToVars: [PlaceType: Multiset<Value>] = [:]
    
    var varMultiset: Multiset<Label> = []
    // Preprocess the net, removing constant on the arc and consuming the value in the corresponding place
    // and creates the list of variables
    if let pre = input[transition] {
      for (place, labels) in pre {
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
        placeToVars[place] = varMultiset
        varMultiset = []
      }
    }
    
    // Get all the possibilities for each labels
    var labelToExprs = associateLabelToExprsForPlace(placeToExprs: placeToExprs, transition: transition)
    
    // Compute a score for each label
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: guards[transition]
    )
    
    let (condWithUniqueLab, condRest) = isolateCondWithUniqueLabel(labelSet: labelSet, conditions: guards[transition])

    labelToExprs = constantPropagation(labelToExprs: labelToExprs, conditionsWithUniqueLabel: condWithUniqueLab)

    // Return the sorted key to expressions list
    let keyToExprs = computeKeyToExprs(
      labelSet: labelSet,
      labelWeights: labelWeights,
      labelToExprs: labelToExprs
    )

    // Construct the mfdd
    var mfddPointer = constructMFDD(
      keyToExprs: keyToExprs,
      transition: transition,
      factory: factory
    )
    
    var keySet: Set<KeyMFDD> = []

    for (key, _) in keyToExprs {
      keySet.insert(key)
    }
  
//    let s: Stopwatch = Stopwatch()
    
    if let conditions = guards[transition] {
      for condition in conditions.sorted(by: {conditionWeights![$0]! > conditionWeights![$1]!}) {
        // Apply guards
        mfddPointer = applyCondition(
          mfddPointer: mfddPointer,
          condition: condition,
          keySet: keySet,
          factory: factory
        )
      }
    }
    
//    print("Time to apply guards: \(s.elapsed.humanFormat)")
    return MFDD(pointer: mfddPointer, factory: factory)
        
  }
  
  func constantPropagation(labelToExprs: [Label: Multiset<Value>], conditionsWithUniqueLabel: [Label: [Pair<Value>]]) -> [Label: Multiset<Value>] {
    
    var labelToExprsTemp = labelToExprs
    
    // Need to create the interpreter here for performance
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    for (labCond, conds) in conditionsWithUniqueLabel {
      for expr in labelToExprs[labCond]! {
        for cond in conds {
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
    transition: TransitionType,
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {

    var keyToExprsForAPlace: [KeyMFDD: Multiset<Value>] =  [:]
    var varToKey: [Label: KeyMFDD] = [:]
    
    for (key, _) in keyToExprs {
      varToKey[key.label] = key
    }
    
    if let pre = input[transition] {
      
      var cache: [[HeroMFDD.Pointer]: HeroMFDD.Pointer] = [:]
      var mfddPointer = factory.zero.pointer
      
      for (_, labels) in pre {
        for label in labels {
          keyToExprsForAPlace[varToKey[label]!] = keyToExprs[varToKey[label]!]!
        }
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
    return factory.zero.pointer
    
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
    transition: TransitionType)
  -> [Label: Multiset<Value>] {
    
    var labelToExprs: [Label: Multiset<Value>] = [:]
    if let pre = input[transition] {
      for (place, labels) in pre {
        for label in labels {
          if let _ = labelToExprs[label] {
            labelToExprs[label] = labelToExprs[label]!.intersection(placeToExprs[place]!)
          } else {
            labelToExprs[label] = placeToExprs[place]!
          }
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
