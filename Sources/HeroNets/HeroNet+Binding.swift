import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
  
  typealias KeyMFDD = Key
  typealias ValueMFDD = String
  
  // createOrder creates a list of pair from a list of string
  // to represent a total order relation. Pair(l,r) => l < r
  func createTotalOrder(keys: [String]) -> [Pair<String>] {
      var r: [Pair<String>] = []
      for i in 0 ..< keys.count {
        for j in i+1 ..< keys.count {
          r.append(Pair(keys[i],keys[j]))
        }
      }
      return r
  }
  
  func isVariable(label: String) -> Bool {
    return label.contains("$")
  }
  
  func isolateVariableName(varName: String) -> String {
    return String(varName.split(separator: "_")[0])
  }
  
  func isSameVar(v1Name: String, v2Name: String) -> Bool {
    return isolateVariableName(varName: v1Name) == isolateVariableName(varName: v2Name)
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
    var variableLists: [[String]] = []
    var varToExprs: [String: Multiset<String>] = [:]
//    var keyToExprs: [Key: Multiset<String>] = [:]
    var arrayKeyToExprs: [[Key: Multiset<String>]] = []
    
    // varSave: Store the original names with its counterpart (e.g.: [x: [x_p0_0, x_p1_1]])
    var listLabel: [String] = []
    var varSave: [String: Set<String>] = [:]
    var newLabelName: String = ""
    
    // Prepare variable names and binds it to their possible expressions
    if let pre = input[transition] {
      for (place, labels) in pre {
        for label in labels {
          newLabelName = "\(label)_\(place)"
          if let _ = varSave[label] {
            newLabelName.append("_\(varSave[label]!.count)")
            varSave[label]!.insert(newLabelName)
          } else {
            newLabelName.append("_0")
            varSave[label] = [newLabelName]
          }
          varToExprs[newLabelName] = marking[place]
          listLabel.append(newLabelName)
        }
        variableLists.append(listLabel)
        listLabel = []
      }
    }
        
    // TODO: Transform this step using MFDD directly
    // If multiple variables appears in different arcs, we do a filterInclude between multiset to keep only valid values.
    for (_, vars) in varSave {
      if vars.count > 1 {
        for var1 in vars {
          for var2 in vars {
            if var1 != var2 {
              varToExprs[var1] = varToExprs[var1]!.filterInclude(varToExprs[var2]!)
            }
          }
        }
      }
    }
    
    // Create the key order
    variableLists = optimizeKeyOrder(variableLists: variableLists, conditions: guards[transition])
        
    let totalOrder = createTotalOrder(keys: variableLists.flatMap({$0}))
    print(totalOrder)
    var keyToExprsTemp: [Key: Multiset<String>] = [:]

    // Create an array of dictionnary where each dictionnary represents a place with labels (as a key) and their corresponding expressions
    for vars in variableLists {
      for var_ in vars {
        keyToExprsTemp[Key(name: var_, couple: totalOrder)] = varToExprs[var_]
      }
      arrayKeyToExprs.append(keyToExprsTemp)
      keyToExprsTemp = [:]
    }
    
    // We sort the dictionnary that becomes an array. The type is implictely changed cause a dictionnary is not ordered.
    // Finally, we reorder all subarray using the biggest key of each.
    var arrayKeyToExprsSorted = arrayKeyToExprs
      .map({(dic: [Key: Multiset<String>]) in
        return dic.sorted(by: {$0.key < $1.key})
      })
      .sorted(by: {$0.first!.value < $1.first!.value})
    
    
    print(arrayKeyToExprsSorted)
    
//    arrayKeyToExprsSorted = arrayKeyToExprsSorted.sorted(by: )

//    arrayKeyToExprs = KeyToExpr.sorted(by: {$0.key.first! < $1.key.first!})
//    print(arrayKeysToExpr)
        
        
    // Construct the mfdd
//    var mfddPointer = constructMFDD(
//      arrayKeysToExpr: arrayKeyToExprs,
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
  
  /// Creates a MFDD pointer an array of key expressions.
  /// It corresponds to all of input arcs for a transition firing
  /// - Parameters:
  ///   - arrayKeyToExp: An array containing a list of keys binds to their possible expressions
  ///   - index: An indicator which the key is currently read.
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every valid possibilities for the given args.
  func constructMFDD(
    arrayKeysToExpr: [Dictionary<[Key], Array<String>>.Element],
    index: Int,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
        
   
    if index == arrayKeysToExpr.count - 1 {
      return constructMFDD(
        keys: arrayKeysToExpr[index].key,
        exprs: arrayKeysToExpr[index].value,
        factory: factory,
        nextPointer: factory.one.pointer
      )
    }
    
    return constructMFDD(
      keys: arrayKeysToExpr[index].key,
      exprs: arrayKeysToExpr[index].value,
      factory: factory,
      nextPointer: constructMFDD(
        arrayKeysToExpr: arrayKeysToExpr,
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
    keys: [Key],
    exprs: [String],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>,
    nextPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer)
  -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
    var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
    if keys.count == 0 {
      return nextPointer
    } else {
      for el in exprs {
        var copyExprs: [String] = exprs
        let index = copyExprs.firstIndex(where: {$0 == el})!
        copyExprs.remove(at: index)
        take[el] = constructMFDD(
          keys: Array(keys.dropFirst()),
          exprs: copyExprs,
          factory: factory,
          nextPointer: nextPointer)
      }
    }
    return factory.node(key: keys.first!, take: take, skip: factory.zero.pointer)
  }
 
  // TODO: Improve heuristic to compute the score
  /// Creates a string Array that optimizes key ordering for MFDD
  /// - Parameters:
  ///   - keyList: Variable of pre arcs of a transition
  ///   - conditions: Conditions of the guard of the transition
  ///   - varSave: A save of the original variable and its counterparts
  /// - Returns:
  ///   A string Array with an optimized order for keys.
  func optimizeKeyOrder(variableLists: [[String]], conditions: [Pair<String>]?) -> [[String]] {
    
    let variableList: [String] = variableLists.flatMap({return $0})
    // If there is no conditions
    guard let _ = conditions else {
      return variableLists
    }
    var keyWeights: [String: Int] = [:]
    var varForCond: [Set<String>] = []
    var varInACond: Set<String> = []
    var multipleSameKey: [String: Int] = [:]
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment it by one each time
    for var_ in variableList {
      if let n = multipleSameKey[self.isolateVariableName(varName: var_)] {
        keyWeights[var_] = 100 + n
        multipleSameKey[self.isolateVariableName(varName: var_)]! += 1
      } else {
        multipleSameKey[self.isolateVariableName(varName: var_)] = 1
        keyWeights[var_] = 100
      }
    }
    
    // To know condition variables
    for pair in conditions! {
      for key in variableList {
        if pair.l.contains(self.isolateVariableName(varName: key)) || pair.r.contains(self.isolateVariableName(varName: key)) {
          varInACond.insert(self.isolateVariableName(varName: key))
        }
      }
      varForCond.append(varInACond)
      varInACond = []
    }
    
    
    // To compute a score
    for (key, _) in keyWeights {
      for cond in varForCond {
        if cond.contains(self.isolateVariableName(varName: key)) {
          if cond.count == 1  {
            keyWeights[key]! += 50
          } else {
            keyWeights[key]! += 10
          }
        }
      }
    }
    
    print(keyWeights)
    
    var listOfVarList: [[String]] = []
    
    // More a key is bigger, more the key will be in the top of the mfdd.
    // Having a big key means to be lower than a small key !
    // For instance: x_weight = 160, y_weight = 120 => x < y
    listOfVarList = variableLists.map({
      stringList in
      return stringList.sorted(by: {keyWeights[$0]! > keyWeights[$1]!})
    })
            
    // Order listOfVarList using variable weights.
    // When a sub Array contains multiple variables, the weight corresponds to the variable with the maximum weight in this sub array
    let res = listOfVarList.sorted(by: {
      (varList1, varList2) -> Bool in
      let max1 = varList1.map({
        keyWeights[$0]!
      }).max()!
      let max2 = varList2.map({
        keyWeights[$0]!
      }).max()!
      return max1 > max2
    })
    
    return res
  }
  
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
