import DDKit

extension HeroNet {
  
  typealias KeyMFDD = String
  typealias ValueMFDD = String
  
//  func fireableBindings() -> MFDD<Key,Value>? {
//    return nil
//  }
  
  func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD], initPointer: MFDD<KeyMFDD,ValueMFDD>.Pointer? = nil) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
    var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
    if vars.count == 0 {
      if let p = initPointer {
        return p
      } else {
        return factory.one.pointer
      }
    }
    for i in values {
      take[i] = fireableBindings(factory: factory, vars: Array(vars.dropFirst()), values: values.filter({$0 != i}), initPointer: initPointer)
    }
    return factory.node(key: vars.first!, take: take, skip: factory.zero.pointer)
  }
  
  /// Creates the fireable bindings of a transition.
  ///
  /// - Parameters:
  ///   - transition: The transition to fire
  ///   - marking: The marking which is used
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   The MFDD which represents all fireable bindings, if there are.
  ///   `nil` otherwise.
  func fireableBindings(for transition: TransitionType, with marking: Marking<PlaceType>, factory: MFDDFactory<KeyMFDD, ValueMFDD>) -> MFDD<KeyMFDD, ValueMFDD>? {
    var pointer: MFDD<KeyMFDD,ValueMFDD>.Pointer? = nil
    var values: [ValueMFDD] = []
    
    let sortKeys = sortPlacesKeys(for: transition)
    let renameSortKeys = renameKeys(for: sortKeys)
    
    // Sort keys by name of places
    // Keys must be ordered to pass into a MFDD.
    // The name of a variable is as follows: nameOfThePlace_variable (e.g.: "p1_x")
    for (place,vars) in renameSortKeys {
      values = marking[place].multisetToArray()
      pointer = fireableBindings(factory: factory, vars: vars, values: values, initPointer: pointer)
    }
    
    return MFDD(pointer: pointer!, factory: factory)
  }
  
  // Rename keys which are ordered in an "optimal" way to keep an order for MFDD
  func renameKeys(for arr: Array<(PlaceType, Array<String>)>) -> Array<(PlaceType, Array<String>)> {
        
    var nbPlace = arr.count-1
    var nbVar = -1
    var res: Array<(PlaceType, Array<String>)> = []
    var subArray: Array<String> = []
    
    for (_ , vars) in arr {
      nbVar += vars.count
    }
    
    for (place, couple) in arr {
      for el in couple {
        subArray.insert(("\(nbPlace)\(nbVar)_\(el)"), at: 0)
        nbVar -= 1
      }
      res.append((place, subArray))
      subArray = []
      nbPlace -= 1
    }
    
    return res
  }
  
  func sortPlacesKeys(for transition: TransitionType) -> Array<(PlaceType, Array<String>)> {
    
    let countVar = countUniqueVarInConditions(for: transition)
    
//    guard !countVar.isEmpty else {
//      return nil
//    }
    
    var dicTemp: [String: Int]
    var placeCountVariables: [PlaceType: Array<(String, Int)>] = [:]
    var res: Array<(PlaceType, Array<String>)> = []
    var subArray: Array<String> = []
    
    // First, sort variable in each place
    // e.g.: sort(p1: [x:2, y:3, z:1]) -> p1: [(z,1), (x,2), (y,3)]
    if let inputTransition = input[transition] {
      for (place, vars) in inputTransition {
        dicTemp = [:]
        for v in vars {
          dicTemp[v] = countVar[v]
        }
        placeCountVariables[place] = dicTemp.sorted(by: {$0.value < $1.value})
      }
    }
    
    // Ordering places by the max of each tuple
    // e.g.: sort(p1: [(x, 3), (y,2)], p2: [(z,1)]) -> [(p2,[(z,1)]), (p1,[(x, 3), (y,2)])]
    // For each place, we get the maximum value of all variable to compare with other places. E.g.: $0.1 = (x,3), $1.1 = (y,2), max((x,3),(y,2)) -> (x,3) and we keep only the value. (x,3).1 -> 3
    let partialRes = placeCountVariables.sorted(by: {
      $0.value.max(by: {$0.1 < $1.1})!.1 < $1.value.max(by: {$0.1 < $1.1})!.1
    })
    
    for (key, couple) in partialRes {
      for (v,_) in couple {
        subArray.append(v)
      }
      res.append((key,subArray))
      subArray = []
    }
    
    return res
    
  }
  
  
  /// Use guards to determine the number of apparition of a variable such that a variable is the only variable in a condition and repeat it for each condition.
  /// E.g.: [("$x", "$y"), ("$x","$x+4"), ("$z", "1")] -> ["x": 1, "y": 0, "z": 1]
  /// We have 3 conditions, but only two have the same variable in each part of the condition.
  func countUniqueVarInConditions(for transition: TransitionType) -> [String: Int] {
    
    var countVar: [String: Int] = [:]
    // Return a list of all variables on the arcs for a specific transition
    var listVariables: [String] = []
    if let inputTransition = input[transition] {
      for (_, vars) in inputTransition {
        listVariables.append(contentsOf: vars)
        for v in vars {
          countVar[v] = 0
        }
      }
    }
    
    // Count the number of time where only one variable is present in a condition for all conditions
    var listCurrentVars: [String] = []
    var s: String
    if let cond = guards[transition] {
      for c in cond {
        s = "\(c.e1) \(c.e2)"
        for v in listVariables {
          if s.contains("$\(v)") {
            if !listCurrentVars.contains(v) {
              listCurrentVars.append(v)
            }
          }
        }
        if listCurrentVars.count == 1 {
          countVar[listCurrentVars[0]]! += 1
        }
        listCurrentVars = []
      }
    }
    return countVar
  }
  
  func isolateConditionsInGuard(for transition: TransitionType) -> [String: [Condition]] {
    
    var listVariables: [String] = []
    var res: [String: [Condition]] = [:]
    var s: String = ""
    
    if let inputTransition = input[transition] {
      for (_, vars) in inputTransition {
        listVariables.append(contentsOf: vars)
        for v in vars {
          res[v] = []
        }
      }
    }
    
    var listCurrentVars: [String] = []
    if let cond = guards[transition] {
      for c in cond {
        s = "\(c.e1) \(c.e2)"
        for v in listVariables {
          if s.contains("$\(v)") {
            if !listCurrentVars.contains(v) {
              listCurrentVars.append(v)
            }
          }
        }
        if listCurrentVars.count == 1 {
          res[listCurrentVars[0]]!.append(c)
        }
        listCurrentVars = []
      }
    }
    
    return res
  }
  
  
}
