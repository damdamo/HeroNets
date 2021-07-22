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
    var listKey: [Key] = []
    
    for vars in variableLists {
      for var_ in vars {
        listKey.append(Key(name: var_, couple: totalOrder))
      }
      mapKeyToExpr[listKey] = mapVarToExpr[Set(vars)]
      listKey = []
    }
    
    let arrayKeyToExpr = mapKeyToExpr.sorted(by: {$0.key.first! < $1.key.first!})
    let mfddPointer = constructMFDD(
      arrayKeyToExpr: arrayKeyToExpr,
      index: 0,
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
  
  /// Creates a dictionnary containing all incorrects solutions for a condition. To avoid to explore all branches, we stop in the exploration when we have seen all keys implies in the condition.
  /// - Parameters:
  ///   - mfdd: A pointer to the current mfdd
  ///   - cond: The condition to check
  ///   - save: The save of the current dictionnary which is constructed
  ///   - listVar: Variable list implies in the condition
  ///   - factory: The factory of the mfdd
  /// - Returns:
  ///   A dictionnary of Key with all values that not satisfy the condition and will be deleted
    func constructExcludingValues(
      mfdd: MFDD<KeyMFDD, ValueMFDD>.Pointer,
      cond: Pair<String>,
      save: [Key: String],
      listKey: [Key],
      factory: MFDDFactory<KeyMFDD, ValueMFDD>
    ) -> [Key: Set<String>] {
  
      // We do not want to explore every keys, therefore if we achieve to explore all keys in conditions we just return it !
      if save.count == listKey.count {
        if !checkCondition(condition: cond, with: save) {
          var dicTemp: [Key: Set<String>] = [:]
          for (k,v) in save {
            dicTemp[k] = [v]
          }
          return dicTemp
        }
        return [:]
      }
  
      var res: [Key: Set<String>] = [:]
      for el in mfdd.pointee.take {
        // If the key is in the condition, we add it ! Otherwise we continue the exploration without adding it !
        if cond.l.contains(mfdd.pointee.key.name) || cond.r.contains(mfdd.pointee.key.name) {
          res = res.merging(
            constructExcludingValues(
              mfdd: el.value,
              cond: cond,
              save: save.merging([mfdd.pointee.key: el.key], uniquingKeysWith: { (current, _) in current }),
              listKey: listKey,
              factory: factory
            ),
            uniquingKeysWith: { (current, new) in current.union(new) }
          )
        } else {
          res = res.merging(
            constructExcludingValues(
              mfdd: el.value,
              cond: cond,
              save: save,
              listKey: listKey,
              factory: factory
            ),
            uniquingKeysWith: { (current, new) in current.union(new) }
          )
        }
      }
      return res
    }

  // Convert the result of the other constructExcludingValues into the good one
  // for the mfdd excluding filter
  func constructExcludingValues(
    mfdd: MFDD<KeyMFDD, ValueMFDD>.Pointer,
    cond: Pair<String>,
    listKey: [Key],
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> [(key: Key, values: [String])] {
    
      let excludingValues = constructExcludingValues(
        mfdd: mfdd,
        cond: cond,
        save: [:],
        listKey: listKey,
        factory: factory)
    
    print(excludingValues)
    return excludingValues.map({(key: $0, values: Array($1))})
    
  }

}
