import DDKit

extension HeroNet {

  public final class GuardFilter: Morphism {
    
    public typealias DD = BindingMFDD
    
    /// The guard to evaluate
    public let condition: Guard
    
    /// Key of the condition
    public let keyCond: [KeyMFDDVar]

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: BindingMFDDFactory
    
    /// Current heroNet
    let heroNet: HeroNet

    /// The morphism's cache.
    private var cache: [BindingMFDD.Pointer: BindingMFDD.Pointer] = [:]

    init(condition: Guard, keyCond: [KeyMFDDVar], factory: BindingMFDDFactory, heroNet: HeroNet) {
      self.condition = condition
      self.keyCond = keyCond
      self.factory = factory
      self.heroNet = heroNet
    }
    
    public func apply(on pointer: BindingMFDD.Pointer, with substitution: [KeyMFDDVar: Val], keyCondOrdered: [KeyMFDDVar]) -> BindingMFDD.Pointer {
      
      if substitution.count == keyCond.count {
        // Transform: [KeyMFDDLabel: Value] -> [Label: Value]
        let s = substitution.reduce([:]) { (partialResult: [Var: Val], tuple: (key: KeyMFDDVar, value: Val)) in
          var result = partialResult
          result[tuple.key.label] = tuple.value
          return result
        }
        if heroNet.checkGuard(condition: condition, with: s) {
          return pointer
        } else {
          return factory.zero.pointer
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
            (value, apply(on: pointer, with: substitution, keyCondOrdered: keyCondOrdered))
          }))
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == keyCondOrdered[0] {
        let take = Dictionary(
          uniqueKeysWithValues: pointer.pointee.take.map({ (value, p) in
            return (value, apply(on: p, with: substitution.merging([pointer.pointee.key: value], uniquingKeysWith: {(_, new) in new}), keyCondOrdered: Array(keyCondOrdered.dropFirst())))
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

    public func apply(on pointer: BindingMFDD.Pointer) -> BindingMFDD.Pointer {
      let substitution: [KeyMFDDVar: Val] = [:]
      return apply(on: pointer, with: substitution, keyCondOrdered: keyCond.sorted(by: { a, b in a < b }))
    }

    public func hash(into hasher: inout Hasher) {
      for key in keyCond {
        hasher.combine(key)
      }
      hasher.combine(condition)
    }

    public static func == (lhs: GuardFilter, rhs: GuardFilter) -> Bool {
      lhs === rhs
    }

  }
  
  public func guardFilter(
    condition: Guard,
    keyCond: [KeyMFDDVar],
    factory: MFDDFactory<KeyMFDDVar, Val>,
    heroNet: HeroNet
  ) -> GuardFilter
  {
    GuardFilter(condition: condition, keyCond: keyCond, factory: factory, heroNet: heroNet)
  }
  
}
