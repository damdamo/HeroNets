import DDKit

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
    var mapVarToExpr: [Set<String>: Multiset<String>] = [:]
    var mapKeyToExpr: [[Key]: Multiset<String>] = [:]
    if let pre = input[transition] {
      for (place, labels) in pre {
        variableLists.append(labels)
        mapVarToExpr[Set(labels)] = marking[place]
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
    
    print(variableLists)
    let arrayKeyToExpr = mapKeyToExpr.sorted(by: {$0.key.first! < $1.key.first!})
    
    print(arrayKeyToExpr)
    
    let mfddPointer = constructMFDD(
      arrayKeyToExpr: arrayKeyToExpr,
      index: 0,
      factory: factory
    )
    
    print(MFDD(pointer: mfddPointer, factory: factory))
    
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
    arrayKeyToExpr: [Dictionary<[Key], Multiset<String>>.Element],
    index: Int,
    factory: MFDDFactory<KeyMFDD, ValueMFDD>
  ) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
        
   
    if index == arrayKeyToExpr.count - 1 {
      return constructMFDD(
        keys: arrayKeyToExpr[index].key,
        exprs: arrayKeyToExpr[index].value.multisetToArray(),
        factory: factory,
        nextPointer: factory.one.pointer
      )
    }
    
    return constructMFDD(
      keys: arrayKeyToExpr[index].key,
      exprs: arrayKeyToExpr[index].value.multisetToArray(),
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
  func constructMFDD(keys: [Key], exprs: [String],
                     factory: MFDDFactory<KeyMFDD, ValueMFDD>,
                     nextPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
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
  
}






//func constructMFDD(arrayKeyToExpr: [Dictionary<[Key], Multiset<String>>.Element],
//                   index: Int,
//                   factory: MFDDFactory<KeyMFDD, ValueMFDD>) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
//  if index == arrayKeyToExpr.count-1 {
//    return factory.one.pointer
//  }
//
//  var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
//
//  for el in arrayKeyToExpr[index].value {
//    var copyExprs: [String] = arrayKeyToExpr[index].value.multisetToArray()
//    let index = copyExprs.firstIndex(where: {$0 == el})!
//    copyExprs.remove(at: index)
//    take[el] = constructMFDD(
//      arrayKeyToExpr: arrayKeyToExpr,
//      index: index+1,
//      factory: factory
//    )
//  }
//
//  return factory.node(key: arrayKeyToExpr[index].key, take: take, skip: factory.zero.pointer)
//}





//  func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD], conditionsForVars: [String: [Condition]], initPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer? = nil) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
//    var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
//    if vars.count == 0 {
//      if let p = initPointer {
//        return p
//      } else {
//        return factory.one.pointer
//      }
//    }
//
//    let key = vars.first!
//    let keyClear = clearVar(key)
//    var conditions: [Condition]
//
//    if let c = conditionsForVars[keyClear] {
//      conditions = c
//    } else {
//      conditions = []
//    }
//
//    var arr: [String] = values
//    for i in values {
//      if checkGuards(conditions: conditions, with: [keyClear:i]) {
//        arr.remove(at: arr.firstIndex(of: i)!)
//        take[i] = fireableBindings(factory: factory, vars: Array(vars.dropFirst()), values: arr, conditionsForVars: conditionsForVars, initPointer: initPointer)
//        arr = values
//      }
//    }
//    return factory.node(key: key, take: take, skip: factory.zero.pointer)
//
//  }
//
//  /// Creates the fireable bindings of a transition.
//  ///
//  /// - Parameters:
//  ///   - transition: The transition to fire
//  ///   - marking: The marking which is used
//  ///   - factory: The factory to construct the MFDD
//  /// - Returns:
//  ///   The MFDD which represents all fireable bindings, if there are.
//  ///   `nil` otherwise.
//  func fireableBindings(for transition: TransitionType, with marking: Marking<PlaceType>, factory: MFDDFactory<KeyMFDD, ValueMFDD>) -> MFDD<KeyMFDD, ValueMFDD>? {
//    var pointer: MFDD<KeyMFDD,ValueMFDD>.Pointer? = nil
//    var values: [ValueMFDD] = []
//    let conditions = isolateConditionsInGuard(for: transition)
//
//    let sortKeys = sortPlacesKeys(for: transition)
//    let renameSortKeys = renameKeys(for: sortKeys)
//
//    // Sort keys by name of places
//    // Keys must be ordered to pass into a MFDD.
//    // The name of a variable is as follows: nameOfThePlace_variable (e.g.: "p1_x")
//    for (place,vars) in renameSortKeys {
//      values = marking[place].multisetToArray()
//      pointer = fireableBindings(factory: factory, vars: vars, values: values, conditionsForVars: conditions, initPointer: pointer)
//    }
//
//    var res = MFDD(pointer: pointer!, factory: factory)
//    var dicClear: [String:String] = [:]
//    // print(partialResult)
//
//    if let condOthers = conditions["others"] {
//      if !condOthers.isEmpty {
//        for el in res {
//          for (k,v) in el {
//            dicClear[clearVar(k)] = v
//          }
//          if !checkGuards(conditions: condOthers, with: dicClear) {
//            res = res.subtracting(factory.encode(family: [el]))
//          }
//        }
//      }
//      return res
//    }
//
//    return nil
//  }
//
//  // Rename keys which are ordered in an "optimal" way to keep an order for MFDD
//  func renameKeys(for arr: Array<(PlaceType, Array<String>)>) -> Array<(PlaceType, Array<String>)> {
//
//    var nbPlace = arr.count-1
//    var nbVar = -1
//    var res: Array<(PlaceType, Array<String>)> = []
//    var subArray: Array<String> = []
//
//    for (_ , vars) in arr {
//      nbVar += vars.count
//    }
//
//    for (place, couple) in arr {
//      for el in couple {
//        subArray.insert(("\(nbPlace)\(nbVar)_\(el)"), at: 0)
//        nbVar -= 1
//      }
//      res.append((place, subArray))
//      subArray = []
//      nbPlace -= 1
//    }
//
//    return res
//  }
//
//  func sortPlacesKeys(for transition: TransitionType) -> Array<(PlaceType, Array<String>)> {
//
//    let countVar = countUniqueVarInConditions(for: transition)
//
////    guard !countVar.isEmpty else {
////      return nil
////    }
//
//    var dicTemp: [String: Int]
//    var placeCountVariables: [PlaceType: Array<(String, Int)>] = [:]
//    var res: Array<(PlaceType, Array<String>)> = []
//    var subArray: Array<String> = []
//
//    // First, sort variable in each place
//    // e.g.: sort(p1: [x:2, y:3, z:1]) -> p1: [(z,1), (x,2), (y,3)]
//    if let inputTransition = input[transition] {
//      for (place, vars) in inputTransition {
//        dicTemp = [:]
//        for v in vars {
//          dicTemp[v] = countVar[v]
//        }
//        placeCountVariables[place] = dicTemp.sorted(by: {$0.value < $1.value})
//      }
//    }
//
//    // Ordering places by the max of each tuple
//    // e.g.: sort(p1: [(x, 3), (y,2)], p2: [(z,1)]) -> [(p2,[(z,1)]), (p1,[(x, 3), (y,2)])]
//    // For each place, we get the maximum value of all variable to compare with other places. E.g.: $0.1 = (x,3), $1.1 = (y,2), max((x,3),(y,2)) -> (x,3) and we keep only the value. (x,3).1 -> 3
//    let partialRes = placeCountVariables.sorted(by: {
//      $0.value.max(by: {$0.1 < $1.1})!.1 < $1.value.max(by: {$0.1 < $1.1})!.1
//    })
//
//    for (key, couple) in partialRes {
//      for (v,_) in couple {
//        subArray.append(v)
//      }
//      res.append((key,subArray))
//      subArray = []
//    }
//
//    return res
//
//  }
//
//
//  /// Use guards to determine the number of apparition of a variable such that a variable is the only variable in a condition and repeat it for each condition.
//  /// E.g.: [("$x", "$y"), ("$x","$x+4"), ("$z", "1")] -> ["x": 1, "y": 0, "z": 1]
//  /// We have 3 conditions, but only two have the same variable in each part of the condition.
//  func countUniqueVarInConditions(for transition: TransitionType) -> [String: Int] {
//
//    var countVar: [String: Int] = [:]
//    // Return a list of all variables on the arcs for a specific transition
//    var listVariables: [String] = []
//    if let inputTransition = input[transition] {
//      for (_, vars) in inputTransition {
//        listVariables.append(contentsOf: vars)
//        for v in vars {
//          countVar[v] = 0
//        }
//      }
//    }
//
//    // Count the number of time where only one variable is present in a condition for all conditions
//    var listCurrentVars: [String] = []
//    var s: String
//    if let cond = guards[transition] {
//      for c in cond {
//        s = "\(c.e1) \(c.e2)"
//        for v in listVariables {
//          if s.contains("\(v)") {
//            if !listCurrentVars.contains(v) {
//              listCurrentVars.append(v)
//            }
//          }
//        }
//        if listCurrentVars.count == 1 {
//          countVar[listCurrentVars[0]]! += 1
//        }
//        listCurrentVars = []
//      }
//    }
//    return countVar
//  }
//
//  /// Isolate each conditions depending variables.
//  /// Goal is to keep all conditions where there is an only variables, to simplify the construction of binding
//  /// E.g.: [cond("x", 2), cond("y", "x"), ...] --> ["x": [cond("x",2)], "y": [], "z": [], "others": [cond("y","x")]]
//  func isolateConditionsInGuard(for transition: TransitionType) -> [String: [Condition]] {
//
//    var listVariables: [String] = []
//    var res: [String: [Condition]] = [:]
//    var s: String = ""
//
//    if let inputTransition = input[transition] {
//      for (_, vars) in inputTransition {
//        listVariables.append(contentsOf: vars)
//        for v in vars {
//          res[v] = []
//        }
//      }
//    }
//    res["others"] = []
//
//    var listCurrentVars: [String] = []
//    if let cond = guards[transition] {
//      for c in cond {
//        s = "\(c.e1) \(c.e2)"
//        for v in listVariables {
//          if s.contains("$\(v)") {
//            if !listCurrentVars.contains(v) {
//              listCurrentVars.append(v)
//            }
//          }
//        }
//        if listCurrentVars.count == 1 {
//          res[listCurrentVars[0]]!.append(c)
//        } else {
//          res["others"]!.append(c)
//        }
//        listCurrentVars = []
//      }
//    }
//
//    return res
//  }
//
//  // Separate the string into a list of string using "_" and take the last string of the list, which is the variable name
//  // E.g.: "00_x" -> x
//  func clearVar(_ v: String) -> String {
//    guard v.contains("_") else {
//      return v
//    }
//    let vTab: [String] = v.components(separatedBy: "_")
//    return vTab[vTab.count-1]
//  }
//
//  // Clear all variables in a string to string dictionary, using clearVar
//  func clearDicVar(_ dicVar: [String:String]) -> [String:String] {
//    var res: [String:String] = [:]
//    for (k,v) in dicVar {
//      res[clearVar(k)] = v
//    }
//    return res
//  }
