import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  typealias KeyMFDD = Key
  typealias ValueMFDD = String
//  typealias Label = (name: String, nb: Int)
  
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
    var labelSet: Set<Label> = []
    
    // Get all the labels
    for labelToExprs in arrayLabelToExprs {
      for (label, _) in labelToExprs {
        labelSet.insert(label)
      }
    }
    
    // Compute a score for each label
    let labelWeights = computeScoreOrder(labelSet: labelSet, conditions: guards[transition])
    
    // Return the sorted key to expressions list
    let keyToExprs = computeSortedArrayKeyToExprs(
      arrayLabelToExprs: arrayLabelToExprs,
      labelSet: labelSet,
      labelWeights: labelWeights
    )
            
    // Construct the mfdd
//    var mfddPointer = constructMFDD(
//      arrayKeyToExprs: arrayKeyToExprs,
//      index: 0,
//      factory: factory
//    )
    
//
//    let arrayKeysToExpr = mapKeysToExpr.sorted(by: {$0.key.first! < $1.key.first!})
//    print(arrayKeysToExpr)
    
//    let varsToConds = isolateCondForVars(variableLists: variableLists, transition: transition)
//    var keysToCond: [[Key]: [Pair<String>]]? = [:]
//
//    if let vToC = varsToConds {
//      for (vars,conds) in vToC {
//        for var_ in vars {
//          listKeyTemp.append(Key(name: var_, couple: totalOrder))
//        }
//        keysToCond![listKeyTemp] = conds
//      }
//    } else {
//      keysToCond = nil
//    }
    
    
    
    // Construct the mfdd
//    var mfddPointer = constructMFDD(
//      arrayKeysToExpr: arrayKeysToExpr,
//      index: 0,
//      factory: factory
//    )
    
    // Apply guards
//    applyGuardFilter(
//      mfddPointer: &mfddPointer,
//      transition: transition,
//      listKey: listKey,
//      factory: factory
//    )
    let mfddPointer = factory.one.pointer
    return MFDD(pointer: mfddPointer, factory: factory)
  }
  
  /// Creates the list of conditions for a list of variable. It means that  we want to isolate for each group of variables (from our net) for each arc which conditions can be applied independantly from other places. Thus, we can isolate conditions for a specific submfdd which does not need any external information. For instance, if we have a condition Pair("$x","$y"), we  will add it if on one arc we have both variables  $x and $y, otherwise it won't be used at this step. When we have just the same variable on a condition, it will be always taken into account.
  ///
  /// - Parameters:
  ///   - variableLists: List of each group of variables
  ///   - transition: The transition for which we want to compute all bindings
  /// - Returns:
  ///   An array that  binds each group of variables with their corresponding independant conditions (that not depends on another variable from another arc).
  func isolateCondForVars(variableLists: [[String]], transition: TransitionType) -> [[String]: [Pair<String>]]? {
    
    guard let _ = guards[transition] else { return nil }
    
    var res: [[String]: [Pair<String>]] = [:]
    var condToVarList: [Pair<String>: Set<String>] = [:]
    let flattenVariableLists = variableLists.flatMap({$0})
    
    if let conditions = guards[transition] {
      for cond in conditions {
        for variable in flattenVariableLists {
          if cond.l.contains(variable) || cond.r.contains(variable) {
            if let _ = condToVarList[cond] {
              condToVarList[cond]!.insert(variable)
            } else {
              condToVarList[cond] = [variable]
            }
          }
        }
      }
    }
    
    for (cond,vars) in condToVarList {
      for variableList in variableLists {
        if vars.isSubset(of: variableList) {
          if let _ = res[variableList] {
            res[variableList]!.append(cond)
          } else {
            res[variableList] = [cond]
          }
        }
      }
    }
    
    return res
  }
  
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
  
  /// Creates a MFDD pointer an array of key expressions.
  /// It corresponds to all of input arcs for a transition firing
  /// - Parameters:
  ///   - arrayKeyToExp: An array containing a list of keys binds to their possible expressions
  ///   - index: An indicator which the key is currently read.
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every valid possibilities for the given args.
//  func constructMFDD(
//    arrayKeyToExprs: [[Key: Multiset<String>]],
//    index: Int,
//    factory: MFDDFactory<KeyMFDD, ValueMFDD>
//  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
//
//
//    if index == arrayKeyToExprs.count - 1 {
//      return constructMFDD(
//        keyToExprs: arrayKeyToExprs[index],
//        factory: factory,
//        nextPointer: factory.one.pointer
//      )
//    }
//
//    return constructMFDD(
//      keyToExprs: arrayKeyToExprs[index],
//      factory: factory,
//      nextPointer: constructMFDD(
//        arrayKeyToExprs: arrayKeyToExprs,
//        index: index+1,
//        factory: factory
//      )
//    )
//
//  }

  
  
  /// Creates a MFDD pointer for a couple of keys and expressions.
  /// It corresponds only to a single input arc that can contains multiple variables.
  /// - Parameters:
  ///   - keys: The label keys of an input arc
  ///   - exprs: The expressions that can be taken by the variables.
  ///   - factory: The factory to construct the MFDD
  ///   - nextPointer: The pointer that links every arcs between them cause we construct a separate mfdd for each list of variables. Hence, we get a logic continuation. This value is Top for the last variable of the MFDD.
  /// - Returns:
  ///   A MFDD pointer that contains every valid possibilities for the given args.
//  func constructMFDD(
//    keyToExprs: [Dictionary<Key, Multiset<String>>.Element],
//    factory: MFDDFactory<KeyMFDD, ValueMFDD>,
//    nextPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer)
//  -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
//    if keyToExprs.count == 0 {
//      return nextPointer
//    } else {
//      var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
//      let (key, exprs) = keyToExprs.first!
//      let rest = Array(keyToExprs.dropFirst())
//      var restTemp = rest
//
//      for el in exprs {
//        for (subKey, subExprs) in rest {
//
//          let index = restTemp!.firstIndex(where: {$0 == subExprs})!
//          restTemp.remove(at: index)
//        }
////        var copyExprs: [String] = exprs
////        let index = copyExprs.firstIndex(where: {$0 == el})!
////        copyExprs.remove(at: index)
//        take[el] = constructMFDD(
//          keys: Array(keys.dropFirst()),
//          exprs: copyExprs,
//          factory: factory,
//          nextPointer: nextPointer)
//      }
//    }
//    return factory.node(key: keys.first!, take: take, skip: factory.zero.pointer)
//  }
  
  func computeScoreOrder(
    labelSet: Set<Label>,
    conditions: [Pair<String>]?)
  -> [Label: Int]? {
    
    // If there is no conditions
    guard let _ = conditions else {
      return nil
    }
    var labelWeights: [Label: Int] = [:]
    var varForCond: [Set<String>] = []
    var varInACond: Set<String> = []
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment its n value, allowing to distingue them
    for label in labelSet {
      labelWeights[label] = 100 + label.n
    }
    
    // To know condition variables
    for pair in conditions! {
      for label in labelSet {
        if pair.l.contains(label.name) || pair.r.contains(label.name) {
          varInACond.insert(label.name)
        }
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
            labelWeights[label]! += 50
          } else {
            labelWeights[label]! += 10
          }
        }
      }
    }
    
    return labelWeights
  }
 
  func computeSortedArrayKeyToExprs(
    arrayLabelToExprs: [[Label: Multiset<String>]],
    labelSet: Set<Label>,
    labelWeights: [Label: Int]?
  ) -> [[Key: Multiset<String>]] {
    
    let totalOrder: [Pair<Label>]
    var keyToExprs: [Key: Multiset<String>] = [:]
    var arrayKeyToExprs: [[Key: Multiset<String>]] = []
    
    if let lw = labelWeights {
      totalOrder = createTotalOrder(
        labels: labelSet.sorted(by: {(label1, label2) -> Bool in
          return lw[label1]! < lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(labels: Array(labelSet))
    }
    
    for labelToExprs in arrayLabelToExprs {
      for (label, exprs) in labelToExprs {
        keyToExprs[Key(label: label, couple: totalOrder)] = exprs
      }
      arrayKeyToExprs.append(keyToExprs)
      keyToExprs = [:]
    }
    

    if let lw = labelWeights {
      return arrayKeyToExprs.sorted(by: {(keyToExpr1, keyToExpr2) -> Bool in
        let max1 = keyToExpr1.map({(key, exprs) -> Int in
          lw[key.label]!
        }).max()!
        let max2 = keyToExpr2.map({(key, exprs) -> Int in
          lw[key.label]!
        }).max()!
        return max1 > max2
      })
    }
    
    return arrayKeyToExprs
  }

  // TODO: Improve heuristic to compute the score
  /// Creates a string Array that optimizes key ordering for MFDD
  /// - Parameters:
  ///   - keyList: Variable of pre arcs of a transition
  ///   - conditions: Conditions of the guard of the transition
  ///   - varSave: A save of the original variable and its counterparts
  /// - Returns:
  ///   A string Array with an optimized order for keys.
//  func optimizeLabelOrder(labelWeights: [Label: Int]) -> [Label] {
//
//
//    var listOfVarList: [[String]] = []
//
//    // More a key is bigger, more the key will be in the top of the mfdd.
//    // Having a big key means to be lower than a small key !
//    // For instance: x_weight = 160, y_weight = 120 => x < y
//    listOfVarList = variableLists.map({
//      stringList in
//      return stringList.sorted(by: {keyWeights[$0]! > keyWeights[$1]!})
//    })
//
//    // Order listOfVarList using variable weights.
//    // When a sub Array contains multiple variables, the weight corresponds to the variable with the maximum weight in this sub array
//    let res = listOfVarList.sorted(by: {
//      (varList1, varList2) -> Bool in
//      let max1 = varList1.map({
//        keyWeights[$0]!
//      }).max()!
//      let max2 = varList2.map({
//        keyWeights[$0]!
//      }).max()!
//      return max1 > max2
//    })
//
//    return res
//  }
  
//  /// Apply each conditions on the current mfdd pointer.
//  /// - Parameters:
//  ///   - mfddPointer: Mfdd pointer that is modified depending on conditions of the transition
//  ///   - conditions: The firing transition
//  ///   - listKey: List of all keys in the mfdd
//  ///   - factory: The factory of the mfdd
//  func applyGuardFilter(
//    mfddPointer: inout MFDD<KeyMFDD, ValueMFDD>.Pointer,
//    transition: TransitionType,
//    listKey: [Key],
//    factory: MFDDFactory<KeyMFDD, ValueMFDD>
//  ) {
//
//    var listKeyForCond: [KeyMFDD] = listKey
//
//    if let conditions = guards[transition] {
//      for cond in conditions {
//        listKeyForCond.removeAll(where: {(key: Key) -> Bool in
//          return !cond.l.contains(key.name) && !cond.r.contains(key.name)
//        })
//        constructExcludingValues(
//          mfddPointer: &mfddPointer,
//          cond: cond,
//          listKey: listKeyForCond,
//          factory: factory
//        )
//        listKeyForCond = listKey
//      }
//    }
//  }
//
//  /// Modify mfddPointer which is inout and apply modification in it if necessary.  We explore the mfdd recursively (as a tree) and keeping a trace of the variable explored. If variables are in conditions, we keep them until we have all of them to test the condition. If the condition is not satisfied, the key points on bottom.
//  /// - Parameters:
//  ///   - mfddPointer: A pointer to the current mfdd
//  ///   - cond: The condition to check
//  ///   - save: The save of the current dictionnary which is constructed
//  ///   - listKey: Key list implies in the condition (do not add others keys)
//  ///   - factory: The factory of the mfdd
//  func constructExcludingValues(
//    mfddPointer: inout MFDD<KeyMFDD, ValueMFDD>.Pointer,
//    cond: Pair<String>,
//    save: [Key: String] = [:],
//    listKey: [Key],
//    factory: MFDDFactory<KeyMFDD, ValueMFDD>
//  ) {
//
//    let x = mfddPointer
//    // If the current key is contained in the condition
//    if cond.l.contains(mfddPointer.pointee.key.name) || cond.r.contains(mfddPointer.pointee.key.name) {
//      // If we read the last key, we have all parameters to evaluate the condition and keeping it if condition is satisfied
//      if save.count + 1 == listKey.count {
//        for (k, _) in mfddPointer.pointee.take {
//          if !checkCondition(
//              condition: cond,
//              with: save.merging([mfddPointer.pointee.key: k], uniquingKeysWith: { (current, _) in current }))
//          {
//            print(MFDD(pointer: mfddPointer, factory: factory))
//            mfddPointer.pointee.take.removeValue(forKey: k)
//            print(MFDD(pointer: mfddPointer, factory: factory))
//          }
//        }
//        // If there is no more valid solution in the  take branch, the whole node becomes bottom
//        if mfddPointer.pointee.take.count == 0 {
//          mfddPointer = factory.zero.pointer
//        }
//      } else {
//        // If It's not the last key, we add it to save and continue the recursion
//        for (k, _) in mfddPointer.pointee.take {
//          constructExcludingValues(
//            mfddPointer: &mfddPointer.pointee.take[k]!,
//            cond: cond,
//            save: save.merging([mfddPointer.pointee.key: k], uniquingKeysWith: { (current, _) in current }),
//            listKey: listKey,
//            factory: factory
//          )
//        }
//      }
//    } else {
//      // If the current k is not contained in the condition, function is recursively called with his children without modifying save
//      for (k, _) in mfddPointer.pointee.take {
//        constructExcludingValues(
//          mfddPointer: &mfddPointer.pointee.take[k]!,
//          cond: cond,
//          save: save,
//          listKey: listKey,
//          factory: factory
//        )
//      }
//
//    }
//  }

}
