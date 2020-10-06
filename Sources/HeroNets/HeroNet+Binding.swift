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
    
    // Sort keys by name of places
    // Keys must be ordered to pass into a MFDD.
    // The name of a variable is as follows: nameOfThePlace_variable (e.g.: "p1_x")
    if let inputTransition = input[transition] {
      for (place, vars) in inputTransition.sorted(by: {"\($0.key)" > "\($1.key)"}) {
        values = marking[place].multisetToArray()
        pointer = fireableBindings(factory: factory, vars: vars.map{"\(place)_\($0)"}, values: values, initPointer: pointer)
      }
    }
    
    return MFDD(pointer: pointer!, factory: factory)
  }
  
  func orderPlacesKeys(for transition: TransitionType) -> Array<(PlaceType, Array<(String, Int)>)>? {
    
    let countVar = countUniqueVarInConditions(with: transition)
    var dicTemp: [String: Int]
    var placeCountVariables: [PlaceType: Array<(String, Int)>] = [:]
    
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
    return placeCountVariables.sorted(by: {
      $0.value.max(by: {$0.1 < $1.1})! < $1.value.max(by: {$0.1 < $1.1})!
    })
    
  }
  
  
  /// Use guards to determine the number of apparition of a variable such that a variable is the only variable in a condition and repeat it for each condition.
  /// E.g.: [("$x", "$y"), ("$x","$x+4"), ("$z", "1")] -> ["x": 1, "z": 1]
  /// We have 3 conditions, but only two have the same variable in each part of the condition.
  func countUniqueVarInConditions(with transition: TransitionType) -> [String: Int] {
    
    // Return a list of all variables on the arcs for a specific transition
    var listVariables: [String] = []
    if let inputTransition = input[transition] {
      for (_, vars) in inputTransition {
        listVariables.append(contentsOf: vars)
      }
    }
    
    // Count the number of time where only one variable is present in a condition for all conditions
    var countVar: [String: Int] = [:]
    var countVarTemp: [String: Int] = [:]
    var s: String
    if let cond = guards[transition] {
      for c in cond {
        s = "\(c.e1) \(c.e2)"
        for v in listVariables {
          if s.contains("$\(v)") {
            if countVarTemp[v] == nil {
              countVarTemp[v] = 1
            } else {
              countVarTemp[v]! += 1
            }
          }
        }
        if countVarTemp.count == 1 {
          if countVar[countVarTemp.first!.key] == nil {
            countVar[countVarTemp.first!.key] = 1
          } else {
            countVar[countVarTemp.first!.key]! += 1
          }
        }
        countVarTemp = [:]
      }
    }
    return countVar
  }
  
}
