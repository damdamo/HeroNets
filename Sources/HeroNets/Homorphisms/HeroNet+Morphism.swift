import DDKit

extension HeroNet {

  public final class GuardFilter: Morphism {

    public typealias DD = BindingMFDD

    public let keys: Set<KeyMFDDVar>
    public let guards: [Guard]
    public let keysToGuards: [Set<KeyMFDDVar>: Set<Guard>]
    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: BindingMFDDFactory

    /// Computed property: A dictionnary that associates keys to guards
    
    /// Current heroNet
    let heroNet: HeroNet

    /// The morphism's cache.
    private var cache: [BindingMFDD.Pointer: BindingMFDD.Pointer] = [:]

    init(keys: Set<KeyMFDDVar>, guards: [Guard], keysToGuards: [Set<KeyMFDDVar>: Set<Guard>], factory: BindingMFDDFactory, heroNet: HeroNet) {
      self.keys = keys
      self.guards = guards
      self.keysToGuards = keysToGuards
      self.factory = factory
      self.heroNet = heroNet
    }

    public func apply(on pointer: BindingMFDD.Pointer) -> BindingMFDD.Pointer {
      let substitution: [KeyMFDDVar: Val] = [:]
      return apply(
        on: pointer,
        with: substitution,
        kToG: keysToGuards,
        keyCondOrdered: keys.sorted(by: { a, b in a < b }))
//                   , keyCondOrdered: keysMFDD.sorted(by: { a, b in a < b }))
    }


    private func apply(
      on pointer: BindingMFDD.Pointer,
      with substitution: [KeyMFDDVar: Val],
      kToG: [Set<KeyMFDDVar>: Set<Guard>],
      keyCondOrdered: [KeyMFDDVar])
    -> BindingMFDD.Pointer {

      var keysToGuardTemp: [Set<KeyMFDDVar>: Set<Guard>] = kToG
      
      // The greater the score of a guard is, the earlier we try to test it
      for (keys, conds) in keysToGuardTemp {
        for cond in conds {
          if keys.isSubset(of: substitution.keys) {
            let s = substitution.reduce([:]) { (partialResult: [Var: Val], tuple: (key: KeyMFDDVar, value: Val)) in
              var result = partialResult
              result[tuple.key.label] = tuple.value
              return result
            }
            
            if heroNet.checkGuard(condition: cond, with: s) {
              keysToGuardTemp.removeValue(forKey: keys)
              if keysToGuardTemp.isEmpty {
                return pointer
              }
            } else {
              return factory.zero.pointer
            }
          }
        }
      }

      // Check for trivial cases.
      guard !factory.isTerminal(pointer)
        else { return pointer }

      // Apply the morphism.
      let result: BindingMFDD.Pointer
      if pointer.pointee.key < keyCondOrdered[0] {
        let take = Dictionary(
          uniqueKeysWithValues: pointer.pointee.take.map({ (value, pointer) in
            (value, apply(on: pointer, with: substitution, kToG: keysToGuardTemp, keyCondOrdered: keyCondOrdered))
          }))
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == keyCondOrdered[0] {
        let take = Dictionary(
          uniqueKeysWithValues: pointer.pointee.take.map({ (value, p) in
            return (value, apply(on: p, with: substitution.merging([pointer.pointee.key: value], uniquingKeysWith: {(_, new) in new}), kToG: keysToGuardTemp, keyCondOrdered: Array(keyCondOrdered.dropFirst())))
          }))
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else {
        return pointer
      }

      return result
    }

    public func hash(into hasher: inout Hasher) {
      for key in keys {
        hasher.combine(key)
      }
      hasher.combine(keysToGuards)
    }

    public static func == (lhs: GuardFilter, rhs: GuardFilter) -> Bool {
      lhs === rhs
    }

  }

  /// Create a GuardFilter homomorphism t
  public func guardFilter(
    keys: Set<KeyMFDDVar>,
    guards: [Guard],
    keysToGuards: [Set<KeyMFDDVar>: Set<Guard>],
    factory: MFDDFactory<KeyMFDDVar, Val>,
    heroNet: HeroNet)
  -> GuardFilter {
    return GuardFilter(
      keys: keys,
      guards: guards,
      keysToGuards: keysToGuards,
      factory: factory,
      heroNet: heroNet)
  }

}


//import DDKit
//
//extension HeroNet {
//
//  public final class GuardFilter: Morphism {
//
//    public typealias DD = BindingMFDD
//
//    /// The guard to evaluate
//    public let condition: Guard
//
//    /// Key of the condition
//    public let keyCond: [KeyMFDDVar]
//
//    /// The factory that creates the nodes handled by this morphism.
//    public unowned let factory: BindingMFDDFactory
//
//    /// Current heroNet
//    let heroNet: HeroNet
//
//    /// The morphism's cache.
//    private var cache: [BindingMFDD.Pointer: BindingMFDD.Pointer] = [:]
//
//    init(condition: Guard, keyCond: [KeyMFDDVar], factory: BindingMFDDFactory, heroNet: HeroNet) {
//      self.condition = condition
//      self.keyCond = keyCond
//      self.factory = factory
//      self.heroNet = heroNet
//    }
//
//    public func apply(on pointer: BindingMFDD.Pointer) -> BindingMFDD.Pointer {
//      let substitution: [KeyMFDDVar: Val] = [:]
//      return apply(on: pointer, with: substitution, keyCondOrdered: keyCond.sorted(by: { a, b in a < b }))
//    }
//
//    private func apply(
//      on pointer: BindingMFDD.Pointer,
//      with substitution: [KeyMFDDVar: Val],
//      keyCondOrdered: [KeyMFDDVar])
//    -> BindingMFDD.Pointer {
//
//      if substitution.count == keyCond.count {
//        // Transform: [KeyMFDDLabel: Value] -> [Label: Value]
//        let s = substitution.reduce([:]) { (partialResult: [Var: Val], tuple: (key: KeyMFDDVar, value: Val)) in
//          var result = partialResult
//          result[tuple.key.label] = tuple.value
//          return result
//        }
//        if heroNet.checkGuard(condition: condition, with: s) {
//          return pointer
//        } else {
//          return factory.zero.pointer
//        }
//      }
//
//      // Check for trivial cases.
//      guard !factory.isTerminal(pointer)
//        else { return pointer }
//
//      // Apply the morphism.
//      let result: BindingMFDD.Pointer
//      if pointer.pointee.key < keyCondOrdered[0] {
//        let take = Dictionary(
//          uniqueKeysWithValues: pointer.pointee.take.map({ (value, pointer) in
//            (value, apply(on: pointer, with: substitution, keyCondOrdered: keyCondOrdered))
//          }))
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: take,
//          skip: factory.zero.pointer)
//      } else if pointer.pointee.key == keyCondOrdered[0] {
//        let take = Dictionary(
//          uniqueKeysWithValues: pointer.pointee.take.map({ (value, p) in
//            return (value, apply(on: p, with: substitution.merging([pointer.pointee.key: value], uniquingKeysWith: {(_, new) in new}), keyCondOrdered: Array(keyCondOrdered.dropFirst())))
//          }))
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: take,
//          skip: factory.zero.pointer)
//      } else {
//        return pointer
//      }
//
//      return result
//    }
//
//    public func hash(into hasher: inout Hasher) {
//      for key in keyCond {
//        hasher.combine(key)
//      }
//      hasher.combine(condition)
//    }
//
//    public static func == (lhs: GuardFilter, rhs: GuardFilter) -> Bool {
//      lhs === rhs
//    }
//
//  }
//
//  /// Create a GuardFilter homomorphism t
//  public func guardFilter(
//    condition: Guard,
//    keyCond: [KeyMFDDVar],
//    factory: MFDDFactory<KeyMFDDVar, Val>,
//    heroNet: HeroNet)
//  -> GuardFilter {
//    GuardFilter(condition: condition, keyCond: keyCond, factory: factory, heroNet: heroNet)
//  }
//
//}
