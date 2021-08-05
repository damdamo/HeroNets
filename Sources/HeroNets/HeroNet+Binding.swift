import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  typealias KeyMFDD = Key
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
    var variableSet: Set<String> = []
    
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
            variableSet.insert(lab)
          }
        }
        placeToVars[place] = varMultiset
        varMultiset = []
      }
    }
    
    // Get all the possibilities for each labels
    let arrayLabelToExprs = associateLabelToExprsForPlace(placeToExprs: placeToExprs, transition: transition)
    var arrayLabelSet: [Set<Label>] = []
    var labelSet: Set<Label> = []
    
    // Get all the labels
    for labelToExprs in arrayLabelToExprs {
      for (label, _) in labelToExprs {
        labelSet.insert(label)
      }
      arrayLabelSet.append(labelSet)
      labelSet = []
    }
    
    // Compute a score for each label
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: arrayLabelSet.reduce(Set([]), {(result, setLabel) in
        result.union(setLabel)
      }),
      conditions: guards[transition]
    )
            
    // Return the sorted key to expressions list
    let arrayKeyToExprs = computeSortedArrayKeyToExprs(
      arrayLabelToExprs: arrayLabelToExprs,
      arrayLabelSet: arrayLabelSet,
      labelWeights: labelWeights
    )
            
    // Construct the mfdd
    let mfddPointer = constructMFDD(
      arrayKeyToExprs: arrayKeyToExprs,
      index: 0,
      factory: factory
    )
    
    let (condWithOnlySameVariable, restConditions) = isolateCondWithSameVariable(variableSet: variableSet, conditions: guards[transition])
    
    var keySet: Set<Key> = []
    
    for keyToExprs in arrayKeyToExprs {
      for (key,_) in keyToExprs {
        keySet.insert(key)
      }
    }
    
    var mfdd = MFDD(pointer: mfddPointer, factory: factory)
    
    if let _ = guards[transition] {
      // Apply guards
      applyConditions(
        mfdd: &mfdd,
        condWithOnlySameVariable: condWithOnlySameVariable,
        restConditions: restConditions,
        conditionWeights: conditionWeights!,
        keySet: keySet,
        factory: factory
      )
    }
    
    return mfdd
  }
  
  func applyConditions(
    mfdd: inout MFDD<KeyMFDD,ValueMFDD>,
    condWithOnlySameVariable: [String: [Pair<String>]],
    restConditions: [Pair<String>],
    conditionWeights: [Pair<String>: Int],
    keySet: Set<Key>,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) {
    
    var morphisms: MFDDMorphismFactory<KeyMFDD, ValueMFDD> { factory.morphisms }
          
    // Conditions with the same variable of the form: ($x, expr) or (expr, $x)
    // Does not work for condition of the form: ($x +  1, 3)
    for (var_, conditions) in condWithOnlySameVariable {
      var value: String = ""
      for condition in conditions {
        if condition.l.contains("$") {
          value = "\(try! interpreter.eval(string: condition.r))"
          if value.contains("function") {
            value = condition.r
          }
        } else {
          value = "\(try! interpreter.eval(string: condition.l))"
          if value.contains("function") {
            value = condition.l
          }
        }
        
        for key in keySet {
          if key.label.name == var_ {
            let morphism = morphisms.filter(containing: [(key: key, values: [value])])
            mfdd = morphism.apply(on: mfdd)
          }
        }
      }
    }
    
    // Test the rest of conditions directly on each value of the MFDD
    // Conditions are sorted by a score, more it is greater, more the condition is prioritized
    for condition in restConditions.sorted(by: {conditionWeights[$0]! > conditionWeights[$1]!}) {
      for binding in mfdd {
        if !checkCondition(condition: condition, with: binding) {
          mfdd = mfdd.subtracting(factory.encode(family: factory.encode(family: [binding])))
        }
      }
    }
    
  }
  
  /// Create a dictionnary of label names bind to conditions where label name is the only to appear in the condition.
  /// A rest is given containing condition that does not match with the precedent statement.
  /// It corresponds to all of input arcs for a transition firing. Care, it only works for condition of the form: ($x, expr) or (expr, $x)
  /// and not of the form: ($x+1, 3) where we  apply an operation on the side of the variable. It is explainedby the fact that we do not evaluate the part with the variable. In this case it's a bit more complicated cause we need to know $x, implying to go inside the mfdd manually.
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
    arrayKeyToExprs: [[Key: Multiset<String>]],
    index: Int,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {


    if index == arrayKeyToExprs.count - 1 {
      return constructMFDD(
        keyToExprs: arrayKeyToExprs[index],
        factory: factory,
        nextPointer: factory.one.pointer
      )
    }

    return constructMFDD(
      keyToExprs: arrayKeyToExprs[index],
      factory: factory,
      nextPointer: constructMFDD(
        arrayKeyToExprs: arrayKeyToExprs,
        index: index+1,
        factory: factory
      )
    )

  }

  
  
  /// Creates a MFDD pointer for a couple of keys and expressions.
  /// It corresponds only to a single input arc that can contains multiple variables.
  /// - Parameters:
  ///   - keys: The label keys of an input arc
  ///   - exprs: The expressions that can be taken by the variables.
  ///   - factory: The factory to construct the MFDD
  ///   - nextPointer: The pointer that links every arcs between them cause we construct a separate mfdd for each list of variables. Hence, we get a logic continuation. This value is Top for the last variable of the MFDD.
  /// - Returns:
  ///   A MFDD pointer that contains every valid possibilities for the given args.
  func constructMFDD(
    keyToExprs: [Key: Multiset<String>],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>,
    nextPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer)
  -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
    if keyToExprs.count == 0 {
      return nextPointer
    } else {
      var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
      let (key, exprs) = keyToExprs.min(by: {(el1, el2) -> Bool in
        el1.key < el2.key
      })!
            
      var rest = keyToExprs
      rest.removeValue(forKey: key)
      var restTemp = rest

      for el in exprs {
        for (subKey, _) in restTemp {
          restTemp[subKey]!.remove(el)
        }
        take[el] = constructMFDD(
          keyToExprs: restTemp,
          factory: factory,
          nextPointer: nextPointer)
        restTemp = rest
      }
      return factory.node(key: key, take: take, skip: factory.zero.pointer)
    }
  }
    
  /// Create a label for each variable and associates the possible expressions. Labels are grouped by places.
  ///
  /// - Parameters:
  ///   - placeToExprs: Marking of each place (that has been modified earlier)
  ///   - transition: The transition for which we want to compute all bindings
  /// - Returns:
  ///   An array of dictionnary from label to multiset of possible expressions
  func associateLabelToExprsForPlace(
    placeToExprs: [PlaceType: Multiset<String>],
    transition: TransitionType)
  -> [[Label: Multiset<String>]] {
    
    var varSaveExprs: [String: [Multiset<String>]] = [:]
    var varSaveNb: [String: Int] = [:]
    var arrayLabelToExprs: [[Label: Multiset<String>]] = []
    var labelToExprs: [Label: Multiset<String>] = [:]
    
    // Save possible expressions for a variable to manage the case where there is the same variable with different expressions (i.e.: The same variable in two or more different places)
    // It allows us to use a filter later to just keep possible values.
    if let pre = input[transition] {
      for (place, labels) in pre {
        for var_ in labels {
          if let _ = varSaveExprs[var_] {
            varSaveExprs[var_]!.append(placeToExprs[place]!)
          } else {
            varSaveExprs[var_] = [placeToExprs[place]!]
          }
        }
      }
    }
    
    var saveExprs: Multiset<String> = []
    
    // In the case of the same variable, we do a filter include, ensuring the variable will have the same possible values between each places.
    // For instance: m1 = ["x": 2, "y": 1, "z": "3"], m2 = ["y": 1, "z": "1"]
    // m1.filterInclude(m2) -> ["y": 1, "z": "3"]
    // It's not an intersection !
    if let pre = input[transition] {
      for (place, labels) in pre {
        for var_ in labels {
          if var_.contains("$") {
            saveExprs = placeToExprs[place]!
            for exprs in varSaveExprs[var_]! {
              saveExprs = saveExprs.filterInclude(exprs)
            }
            if let n = varSaveNb[var_] {
              labelToExprs[Label(name: var_, n: n)] = saveExprs
              varSaveNb[var_]! += 1
            } else {
              labelToExprs[Label(name: var_, n: 0)] = saveExprs
              varSaveNb[var_] = 1
            }
            saveExprs = []
          }
        }
        arrayLabelToExprs.append(labelToExprs)
        labelToExprs = [:]
      }
    }
    
    return arrayLabelToExprs
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
      labelWeights[label] = 100 + label.n
    }
    
    for condition in conditions! {
      conditionWeights[condition] = 100
    }
    
    // To know condition variables
    for condition in conditions! {
      for label in labelSet {
        if condition.l.contains(label.name) || condition.r.contains(label.name) {
          varInACond.insert(label.name)
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
        if cond.contains(label.name) {
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
  ///   - arrayLabelToExprs: An array of grouped dictionnary that binds label to their expressions
  ///   - labelSet: The set of labels
  ///   - labelWeights: The weight of labels
  /// - Returns:
  ///   A sorted array that binds each key to their expressions, grouped by places and sorted using label weights
  func computeSortedArrayKeyToExprs(
    arrayLabelToExprs: [[Label: Multiset<String>]],
    arrayLabelSet: [Set<Label>],
    labelWeights: [Label: Int]?
  ) -> [[Key: Multiset<String>]] {
    
    let totalOrder: [Pair<Label>]
    var keyToExprs: [Key: Multiset<String>] = [:]
    var arrayKeyToExprs: [[Key: Multiset<String>]] = []
    
    if let lw = labelWeights {
      var weightLabelsGrouped: [[Label: Int]] = []
      var weightLabels: [Label: Int] = [:]
      
      for labelSet in arrayLabelSet {
        for label in labelSet {
          weightLabels[label] = lw[label]
        }
        weightLabelsGrouped.append(weightLabels)
        weightLabels = [:]
      }
      
      // Sort dictionnaries using the greater weight in each of them
      weightLabelsGrouped = weightLabelsGrouped.sorted(
        by: {(labelToWeight1, labelToWeight2) -> Bool in
          let max1 = labelToWeight1.map({(key, weight) -> Int in
            return weight
          }).max()!
          let max2 = labelToWeight2.map({(key, weight) -> Int in
            return weight
          }).max()!
          return max1 > max2
      })
      
      // Goal to achieve: Goes  from [[x0:161,y:120], [x1:160]] -> [x0,y,x1] to allow to create a total order
      // First step: We order each dic into the array (e.g.: [x: 160, y: 120, z: 180] -> [z: 180, x: 160, y: 120])
      // Second step: Keep only the key (e.g.: [z: 180, x: 160, y: 120] -> [z,x,y])
      // Last step: Flatten all arrays (e.g.: [[x,y], [z]] -> [x,y,z])
      let arrayLabelsGrouped = Array(
        weightLabelsGrouped
        .map({(labelToWeight: [Label: Int]) -> [Label] in
          let labelSorted = labelToWeight.sorted(by: {$0.value > $1.value})
          return labelSorted.map({$0.key})
        }))
        .flatMap({$0})
      totalOrder = createTotalOrder(labels: arrayLabelsGrouped)
    } else {
      totalOrder = createTotalOrder(
        labels: Array(arrayLabelSet.reduce(Set([]), {(result, setLabel) in result.union(setLabel)}))
      )
    }
    
    for labelToExprs in arrayLabelToExprs {
      for (label, exprs) in labelToExprs {
        keyToExprs[Key(label: label, couple: totalOrder)] = exprs
      }
      arrayKeyToExprs.append(keyToExprs)
      keyToExprs = [:]
    }

    // [[x], [y, z] with [x: 211, y: 212, z: 42] -> [[y,z],[x]]
    // The smallest key has the biggest score. If score(x) = 211 and score(y) = 212 => y < x
    return arrayKeyToExprs.sorted(by: {(keyToExpr1, keyToExpr2) -> Bool in
      let maxKey1 = keyToExpr1.sorted(by: {$0.key < $1.key}).first!.key
      let maxKey2 = keyToExpr2.sorted(by: {$0.key < $1.key}).first!.key
      return maxKey1 < maxKey2
    })
    
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


//  /// Creates the list of conditions for a list of variable. It means that  we want to isolate for each group of variables (from our net) for each arc which conditions can be applied independantly from other places. Thus, we can isolate conditions for a specific submfdd which does not need any external information. For instance, if we have a condition Pair("$x","$y"), we  will add it if on one arc we have both variables  $x and $y, otherwise it won't be used at this step. When we have just the same variable on a condition, it will be always taken into account.
//  ///
//  /// - Parameters:
//  ///   - variableLists: List of each group of variables
//  ///   - transition: The transition for which we want to compute all bindings
//  /// - Returns:
//  ///   An array that  binds each group of variables with their corresponding independant conditions (that not depends on another variable from another arc).
//  func isolateCondForVars(variableLists: [[String]], transition: TransitionType) -> [[String]: [Pair<String>]]? {
//
//    guard let _ = guards[transition] else { return nil }
//
//    var res: [[String]: [Pair<String>]] = [:]
//    var condToVarList: [Pair<String>: Set<String>] = [:]
//    let flattenVariableLists = variableLists.flatMap({$0})
//
//    if let conditions = guards[transition] {
//      for cond in conditions {
//        for variable in flattenVariableLists {
//          if cond.l.contains(variable) || cond.r.contains(variable) {
//            if let _ = condToVarList[cond] {
//              condToVarList[cond]!.insert(variable)
//            } else {
//              condToVarList[cond] = [variable]
//            }
//          }
//        }
//      }
//    }
//
//    for (cond,vars) in condToVarList {
//      for variableList in variableLists {
//        if vars.isSubset(of: variableList) {
//          if let _ = res[variableList] {
//            res[variableList]!.append(cond)
//          } else {
//            res[variableList] = [cond]
//          }
//        }
//      }
//    }
//
//    return res
//  }
