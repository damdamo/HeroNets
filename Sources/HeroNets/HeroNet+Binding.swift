import DDKit

extension HeroNet {
  
  typealias KeyMFDD = String
  typealias ValueMFDD = String
  
//  func fireableBindings() -> MFDD<Key,Value>? {
//    return nil
//  }
  
  func fireableBindingsRec(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD,ValueMFDD>.Pointer {
    var take: [ValueMFDD: MFDD<KeyMFDD,ValueMFDD>.Pointer] = [:]
    if vars.count == 0 {
      return factory.one.pointer
    }
    for i in values {
      take[i] = fireableBindingsRec(factory: factory, vars: Array(vars.dropFirst()), values: values.filter({$0 != i}))
    }
    return factory.node(key: vars.first!, take: take, skip: factory.zero.pointer)
  }
  
//   Compute the bindings for all values depending of the variables
  func fireableBindings(factory: MFDDFactory<KeyMFDD, ValueMFDD>, vars: [KeyMFDD], values: [ValueMFDD]) -> MFDD<KeyMFDD, ValueMFDD> {
    let pointer = fireableBindingsRec(factory: factory, vars: vars, values: values)
    return MFDD(pointer: pointer, factory: factory)
  }
}
