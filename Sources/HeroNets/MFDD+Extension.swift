import DDKit
import Interpreter

extension MFDD {

  public final class GuardFilter: Morphism {

    public typealias DD = MFDD
    
    /// The guard to evaluate
    public let condition: Pair<Value>
    
    /// Key vars
    public let keyCond: [Key]
    
    /// Interpret
    public let interpreter: Interpreter

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

//    public var lowestRelevantKey: Key { subsVars.min(by: { a, b in a < b })! }

    init(condition: Pair<Value>, keyCond: [Key], interpreter: Interpreter, factory: MFDDFactory<Key, Value>) {
      self.condition = condition
      self.keyCond = keyCond
      self.interpreter = interpreter
      self.factory = factory
    }
    
    public func apply(on pointer: MFDD.Pointer, with substitution: [Key: Value], keyCondOrdered: [Key]) -> MFDD.Pointer {
      
      if substitution.count == keyCond.count {
        if checkGuards(conditions: [condition], with: substitution) {
          return pointer
        } else {
          return factory.zero.pointer
        }
      }
      
      // Check for trivial cases.
      guard !factory.isTerminal(pointer)
        else { return pointer }

      // Query the cache.
      if let result = cache[pointer] {
        return result
      }
      
      // Apply the morphism.
      let result: MFDD.Pointer
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

      cache[pointer] = result
      return result
    }

    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
      let substitution: [Key: Value] = [:]
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

    // Check guards of a transition
    public func checkGuards(conditions: [Pair<Value>], with binding: [Key: Value]) -> Bool {
      var lhs: String = ""
      var rhs: String = ""
      for condition in conditions {
        lhs = bindingSubstitution(str: condition.l, binding: binding)
        rhs = bindingSubstitution(str: condition.r, binding: binding)
        // Check if both term are equals, thanks to the syntactic equivalence !
        // Moreover, allows to compare functions in a syntactic way
        if lhs != rhs {
          let v1 = try! interpreter.eval(string: lhs)
          let v2 = try! interpreter.eval(string: rhs)
          // If values are different and not are signature functions
          if "\(v1)" != "\(v2)" || "\(v1)".contains("function") {
            return false
          }
        }
      }

      return true
    }

    /// Substitute variables inside a string by corresponding binding
    /// Care, variables in the string must begin by a $. (e.g.: "$x + 1")
    public func bindingSubstitution(str: Value, binding: [Key: Value]) -> String {
      var res: String = "\(str)"
      for el in binding {
        res = res.replacingOccurrences(of: "\(el.key)", with: "\(el.value)")
      }
      return res
    }
    
  }
  
}

extension MFDDMorphismFactory {
  public func guardFilter(
    condition: Pair<Value>,
    keyCond: [Key],
    interpreter: Interpreter,
    factory: MFDDFactory<Key,Value>
  ) -> MFDD<Key, Value>.GuardFilter
  {
    MFDD.GuardFilter(condition: condition, keyCond: keyCond, interpreter: interpreter, factory: factory)
  }
}

  
//extension MFDD {
//
//  public final class GuardFilter: Morphism, MFDDSaturable {
//
//    public typealias DD = MFDD
//
//    /// The substitution list of variables by this morphism.
//    public let subsVars: [Key]
//
//    /// The guard to evaluate
//    public let condition: Pair<Value>
//
//    /// The next morphism to apply once the first assignment has been processed.
//    private var next: SaturatedMorphism<GuardFilter>?
//
//    /// The factory that creates the nodes handled by this morphism.
//    public unowned let factory: MFDDFactory<Key, Value>
//
//    /// The morphism's cache.
//    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]
//
//    public var lowestRelevantKey: Key { subsVars.min(by: { a, b in a < b })! }
//
//    init(subsVars: [Key], condition: Pair<Value>, factory: MFDDFactory<Key, Value>) {
//
//      self.subsVars = subsVars.sorted(by: { a, b in a < b })
//      self.condition = condition
//      self.next = subsVars.count > 1
//        ? factory.morphisms.saturate(
//          factory.morphisms.guardFilter(subsVars: self.subsVars.dropFirst(), condition: condition))
//        : nil
//
//      self.factory = factory
//    }
//
//    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
//      // Check for trivial cases.
//      guard !factory.isTerminal(pointer)
//        else { return pointer }
//
//      // Query the cache.
//      if let result = cache[pointer] {
//        return result
//      }
//
//
//      // Apply the morphism.
//      let result: MFDD.Pointer
//      if pointer.pointee.key < subsVars[0] {
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: pointer.pointee.take.mapValues(apply(on:)),
//          skip: factory.zero.pointer)
//      } else if pointer.pointee.key == subsVars[0] {
//        var take: [Value: MFDD.Pointer] = pointer.pointee.take
//        for value in subsVars[0].values {
//          take[value] = nil
//        }
//
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: next != nil ? take.mapValues(next!.apply(on:)) : take,
//          skip: factory.zero.pointer)
//      } else {
//        result = next?.apply(on: pointer) ?? pointer
//      }
//
//      cache[pointer] = result
//      return result
//    }
//
//    public func hash(into hasher: inout Hasher) {
//      for key in subsVars {
//        hasher.combine(key)
//        hasher.combine(condition)
//      }
//    }
//
//    public static func == (lhs: GuardFilter, rhs: GuardFilter) -> Bool {
//      lhs === rhs
//    }
//
//  }
//
//}
//
//extension MFDDMorphismFactory {
//  /// Creates an _guard filter_ morphism.
//  ///
//  /// - Parameter assignments: A sequence with the assignments that the member must not contain.
//  public func guardFilter<S>(subsVars: S, condition: Pair<Value>) -> MFDD<Key, Value>.GuardFilter
//    where S: Sequence, S.Element == Key
//  {
//    let morphism = uniquify(MFDD.GuardFilter(subsVars: Array(subsVars), condition: condition, factory: nodeFactory))
//    return morphism
//  }
//}
