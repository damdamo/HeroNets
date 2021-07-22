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
    
    // All variables imply in the transition firing
    var variableLists: [[String]] = []
    // All possible values that can be taken by each variable (then key)
    var mapVarToExpr: [Set<String>: Array<String>] = [:]
    var mapKeyToExpr: [[Key]: Array<String>] = [:]
    if let pre = input[transition] {
      for (place, labels) in pre {
        variableLists.append(labels)
        mapVarToExpr[Set(labels)] = marking[place].multisetToArray()
      }
    }
    
    variableLists = optimizeKeyOrder(variableLists: variableLists, conditions: guards[transition])
    let totalOrder = createTotalOrder(keys: variableLists.flatMap({$0}))
    var listKeyTemp: [Key] = []
    var listKey: [Key] = []
    
    for vars in variableLists {
      for var_ in vars {
        listKey.append(Key(name: var_, couple: totalOrder))
        listKeyTemp.append(Key(name: var_, couple: totalOrder))
      }
      mapKeyToExpr[listKeyTemp] = mapVarToExpr[Set(vars)]
      listKeyTemp = []
    }
    
    let arrayKeyToExpr = mapKeyToExpr.sorted(by: {$0.key.first! < $1.key.first!})
    
    // Construct the mfdd
    var mfddPointer = constructMFDD(
      arrayKeyToExpr: arrayKeyToExpr,
      index: 0,
      factory: factory
    )
    
//     Apply guards
    applyGuardFilter(
      mfddPointer: &mfddPointer,
      transition: transition,
      listKey: listKey,
      factory: factory
    )
        
    return MFDD(pointer: mfddPointer, factory: factory)
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
    arrayKeyToExpr: [Dictionary<[Key], Array<String>>.Element],
    index: Int,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
        
   
    if index == arrayKeyToExpr.count - 1 {
      return constructMFDD(
        keys: arrayKeyToExpr[index].key,
        exprs: arrayKeyToExpr[index].value,
        factory: factory,
        nextPointer: factory.one.pointer
      )
    }
    
    return constructMFDD(
      keys: arrayKeyToExpr[index].key,
      exprs: arrayKeyToExpr[index].value,
      factory: factory,
      nextPointer: constructMFDD(
        arrayKeyToExpr: arrayKeyToExpr,
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
  ///   - mapVarToExpr: Mapping from var to expr, only used to capture variables by group of arcs
  /// - Returns:
  ///   A string Array with an optimized order for keys.
  func optimizeKeyOrder(variableLists: [[String]], conditions: [Pair<String>]?) -> [[String]] {
    
    let variableList: [String] = variableLists.flatMap({return $0})
    // If there is no conditions
    guard let _ = conditions else {
      return variableLists
    }
    var keyWeights: [String: Int] = [:]
    var countVarForCond: [[String: Bool]] = []
    var countVar: [String: Bool] = [:]
    
    // Initialize the score to 1 for each variable
    for key in variableList {
      keyWeights[key] = 1
    }
    
    // To know condition variables
    for pair in conditions! {
      for key in variableList {
        countVar[key] = pair.l.contains(key) || pair.r.contains(key)
      }
      countVarForCond.append(countVar)
      countVar = [:]
    }
    
    // To compute a score
    for  el in countVarForCond {
      if el.count == 1 {
        keyWeights[el.first!.key]! += 5
      } else {
        for key in variableList {
          if el[key]! {
            keyWeights[key]! += 1
          }
        }
      }
    }
    
    var listOfVarList: [[String]] = []
    
    listOfVarList = variableLists.map({
      stringList in
      return stringList.sorted(by: {keyWeights[$0]! < keyWeights[$1]!})
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
      return max1 < max2
    })
    
    return res
  }
  
  /// Apply each conditions on the current mfdd pointer.
  /// - Parameters:
  ///   - mfddPointer: Mfdd pointer that is modified depending on conditions of the transition
  ///   - conditions: The firing transition
  ///   - listKey: List of all keys in the mfdd
  ///   - factory: The factory of the mfdd
  func applyGuardFilter(
    mfddPointer: inout MFDD<KeyMFDD, ValueMFDD>.Pointer,
    transition: TransitionType,
    listKey: [Key],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) {
    
    var listKeyForCond: [KeyMFDD] = listKey
    
    if let conditions = guards[transition] {
      for cond in conditions {
        listKeyForCond.removeAll(where: {(key: Key) -> Bool in
          return !cond.l.contains(key.name) && !cond.r.contains(key.name)
        })
        constructExcludingValues(
          mfddPointer: &mfddPointer,
          cond: cond,
          listKey: listKeyForCond,
          factory: factory
        )
        listKeyForCond = listKey
      }
    }
  }
  
  /// Modify mfddPointer which is inout and apply modification in it if necessary.  We explore the mfdd recursively (as a tree) and keeping a trace of the variable explored. If variables are in conditions, we keep them until we have all of them to test the condition. If the condition is not satisfied, the key points on bottom.
  /// - Parameters:
  ///   - mfddPointer: A pointer to the current mfdd
  ///   - cond: The condition to check
  ///   - save: The save of the current dictionnary which is constructed
  ///   - listKey: Key list implies in the condition (do not add others keys)
  ///   - factory: The factory of the mfdd
  func constructExcludingValues(
    mfddPointer: inout MFDD<KeyMFDD, ValueMFDD>.Pointer,
    cond: Pair<String>,
    save: [Key: String] = [:],
    listKey: [Key],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) {

    // If the current key is contained in the condition
    if cond.l.contains(mfddPointer.pointee.key.name) || cond.r.contains(mfddPointer.pointee.key.name) {
      // If we read the last key, we have all parameters to evaluate the condition and keeping it if condition is satisfied
      if save.count + 1 == listKey.count {
        for (k, _) in mfddPointer.pointee.take {
          if !checkCondition(
              condition: cond,
              with: save.merging([mfddPointer.pointee.key: k], uniquingKeysWith: { (current, _) in current })
          ) {
            mfddPointer.pointee.take[k] = factory.zero.pointer
          }
        }
        // If It's not the last key, we add it to save and continue the recursion
      } else {
        for (k, _) in mfddPointer.pointee.take {
          constructExcludingValues(
            mfddPointer: &mfddPointer.pointee.take[k]!,
            cond: cond,
            save: save.merging([mfddPointer.pointee.key: k], uniquingKeysWith: { (current, _) in current }),
            listKey: listKey,
            factory: factory
          )
        }
      }
    } else {
      // If the current k is not contained in the condition, function is recursively called with his children without modifying save
      for (k, _) in mfddPointer.pointee.take {
        constructExcludingValues(
          mfddPointer: &mfddPointer.pointee.take[k]!,
          cond: cond,
          save: save,
          listKey: listKey,
          factory: factory
        )
      }
      
    }
  }

}
