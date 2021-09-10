import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  //Label: Type of keys
  typealias Label = String
  typealias KeyMFDD = Key<String>
  typealias ValueMFDD = String
  
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
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD> {
    
    // All variables imply in the transition firing keeping the group by arc
    var labelSet: Set<String> = []
    
    // placeToExprs: Expressions contain in a place
    // placeToVars: Vars related to a place
    var placeToExprs: [PlaceType: Multiset<String>] = [:]
    var placeToVars: [PlaceType: Multiset<String>] = [:]
    
    var varMultiset: Multiset<String> = []
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
    let labelToExprs = associateLabelToExprsForPlace(placeToExprs: placeToExprs, transition: transition)
    
    // Compute a score for each label
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: guards[transition]
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
      transition: transition,
      factory: factory
    )
    
    var keySet: Set<KeyMFDD> = []

    for (key, _) in keyToExprs {
      keySet.insert(key)
    }
  
    let s: Stopwatch = Stopwatch()
    
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
    
    print("Time to apply guards: \(s.elapsed.humanFormat)")
    return MFDD(pointer: mfddPointer, factory: factory)
        
  }
  
  func applyCondition(
    mfddPointer: MFDD<KeyMFDD, ValueMFDD>.Pointer,
    condition: Pair<String>,
    keySet: Set<KeyMFDD>,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD, ValueMFDD>.Pointer {
    
    var morphisms: MFDDMorphismFactory<KeyMFDD, ValueMFDD> { factory.morphisms }
    let keyCond = keySet.filter({(key) in
      if condition.l.contains(key.label) || condition.r.contains(key.label) {
        return true
      }
      return false
    })
        
    let morphism = morphisms.guardFilter(condition: condition, keyCond: Array(keyCond), interpreter: interpreter, factory: factory)
    
    return morphism.apply(on: mfddPointer)
    
  }
  
  
  /// Create a dictionnary of label names bind to conditions where label name is the only to appear in the condition.
  /// A rest is given containing condition that does not match with the precedent statement.
  /// It corresponds to all of input arcs for a transition firing. Care, it only works for condition of the form: ($x, expr) or (expr, $x)
  /// and not of the form: ($x+1, 3) where we  apply an operation on the side of the variable. It is explained by the fact that we do not evaluate the part with the variable. In this case it's a bit more complicated cause we need to know $x, implying to go inside the mfdd manually.
  /// - Parameters:
  ///   - variableSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   A tuple where the first element is the label name binds to a list of condition where the label name is the only variable. The second element is the list of conditions minus conditions that are valid for the first part of the tuple.
  func isolateCondWithSameVariable(variableSet: Set<String>, conditions: [Pair<String>]?) -> ([String: [Pair<String>]], [Pair<String>]) {
    
    var varSetTemp: Set<String> = []
    var condWithOnlySameVariable: [String: [Pair<String>]] = [:]
    var restConditions: [Pair<String>] = []
    
    if let conds = conditions {
      for cond in conds {
        for var_ in variableSet {
          if cond.l.contains(var_) || cond.r.contains(var_) {
            varSetTemp.insert(var_)
          }
        }
        // Check that we have the same variable, and one of both side contains just this variable
        if varSetTemp.count == 1 &&
            (cond.l == varSetTemp.first! || cond.r == varSetTemp.first!){
          if let _ = condWithOnlySameVariable[varSetTemp.first!] {
            condWithOnlySameVariable[varSetTemp.first!]!.append(cond)
          } else {
            condWithOnlySameVariable[varSetTemp.first!] = [cond]
          }
        } else {
          restConditions.append(cond)
        }
        varSetTemp = []
      }
    }
    return (condWithOnlySameVariable, restConditions)

  }
  
  /// Creates a MFDD pointer an array of key expressions.
  /// It corresponds to all of input arcs for a transition firing
  /// - Parameters:
  ///   - arrayKeyToExp: An array containing a list of keys binds to their possible expressions
  ///   - index: An indicator which the key is currently read.
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every valid possibilities for the given args.
  func constructMFDD(
    keyToExprs: [KeyMFDD: Multiset<String>],
    transition: TransitionType,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {

    var keyToExprsForAPlace: [KeyMFDD: Multiset<String>] =  [:]
    var varToKey: [Label: KeyMFDD] = [:]
    
    for (key, _) in keyToExprs {
      varToKey[key.label] = key
    }
    
    if let pre = input[transition] {
      
      var cache: [[MFDD<KeyMFDD,ValueMFDD>.Pointer]: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
      var mfddPointer = factory.zero.pointer
      
      for (_, labels) in pre {
        for label in labels {
          keyToExprsForAPlace[varToKey[label]!] = keyToExprs[varToKey[label]!]!
        }
        let mfddTemp = constructMFDD(keyToExprs: keyToExprsForAPlace, factory: factory)
        
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
  
  func constructMFDD(
    keyToExprs: [KeyMFDD: Multiset<String>],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key,multiset) = keyToExprs.sorted(by: {$0 < $1}).first {
      var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
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
    placeToExprs: [PlaceType: Multiset<String>],
    transition: TransitionType)
  -> [Label: Multiset<String>] {
    
    var labelToExprs: [Label: Multiset<String>] = [:]
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
    conditions: [Pair<String>]?)
  -> ([Label: Int]?, [Pair<String>: Int]?) {
    
    // If there is no conditions
    guard let _ = conditions else {
      return (nil, nil)
    }
    var labelWeights: [Label: Int] = [:]
    var conditionWeights: [Pair<String>: Int] = [:]
    var varForCond: [Set<String>] = []
    var varInACond: Set<String> = []
    
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
          varInACond.insert(label)
        }
      }
      
      // Compute condition weights
      if varInACond.count != 0 {
        conditionWeights[condition]! *= 2/varInACond.count
      } else {
        conditionWeights[condition]! = 0
      }
      
      varForCond.append(varInACond)
      varInACond = []
    }
    
    // To compute a score
    // If a condition contains the same variable, it earns 50 points
    // If a condition contains a variable with other variables, every variables earn 10 points
    for (label, _) in labelWeights {
      for cond in varForCond {
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
    labelToExprs: [Label: Multiset<String>]
  ) -> [KeyMFDD: Multiset<String>] {

    let totalOrder: [Pair<Label>]
    var keyToExprs: [Key<Label>: Multiset<String>] = [:]
    
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
  
  /// Substitute variables inside a string by corresponding binding
  /// Care, variables in the string must begin by a $. (e.g.: "$x + 1")
  func bindingSubstitution(str: String, binding: [Key<Label>: String]) -> String {
    var res: String = str
    for el in binding {
      res = res.replacingOccurrences(of: "\(el.key.label)", with: "\(el.value)")
    }
    return res
  }
  
  func checkCondition(condition: Pair<String>, with binding: [KeyMFDD: String]) -> Bool {
    let lhs: String = bindingSubstitution(str: condition.l, binding: binding)
    let rhs: String = bindingSubstitution(str: condition.r, binding: binding)
    
    if lhs != rhs {
      let v1 = try! interpreter.eval(string: lhs)
      let v2 = try! interpreter.eval(string: rhs)
      // If values are different and not are signature functions
      if "\(v1)" != "\(v2)" || "\(v1)".contains("function") {
        return false
      }
    }
    return true
  }
  
}
