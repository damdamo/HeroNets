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
  
//   Compute the bindings for all values depending of the variables
//  func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD, ValueMFDD> {
//    let pointer = fireableBindings(factory: factory, vars: vars, values: values)
//    return MFDD(pointer: pointer, factory: factory)
//  }
  
  
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
    if let inputTransition = input[transition]?.sorted(by: {"\($0.key)" > "\($1.key)"}) {
      for (place, vars) in inputTransition {
        values = marking[place].multisetToArray()
        pointer = fireableBindings(factory: factory, vars: vars.map{"\(place)_\($0)"}, values: values, initPointer: pointer)
      }
    }
    return MFDD(pointer: pointer!, factory: factory)
  }
}
