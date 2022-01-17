import DDKit

extension MFDD
where Key: Place, Value == Multiset<Val> {

  /// Allow to compute the result of a firing for pre condition.
  /// Results of bindings with pre arcs is removed from the marking
  public final class ExclusiveFilterMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments filtered by this morphism.
    public let assignments: [(key: Key, value: Value)]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<ExclusiveFilterMarking>?

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignments.min(by: { a, b in a.key < b.key })!.key }

    init(assignments: [(key: Key, value: Value)], factory: MFDDFactory<Key, Value>) {
      assert(!assignments.isEmpty, "Sequence of assignments to filter is empty.")

      self.assignments = assignments.sorted(by: { a, b in a.key < b.key })
      self.next = assignments.count > 1
        ? factory.morphisms.saturate(
          factory.morphisms.filterMarking(excluding: self.assignments.dropFirst()))
        : nil

      self.factory = factory
    }

    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
      // Check for trivial cases.
      if factory.isTerminal(pointer) {
        return pointer
      }
      
      // Query the cache.
      if let result = cache[pointer] {
        return result
      }

      // Apply the morphism.
      let result: MFDD.Pointer
      if pointer.pointee.key < assignments[0].key {
        result = factory.node(
          key: pointer.pointee.key,
          take: pointer.pointee.take.mapValues(apply(on:)),
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == assignments[0].key {
        var take: [Value: MFDD.Pointer] = [:]
        var newKey: Multiset<Val>
        
        for (key, pointer) in pointer.pointee.take {
          newKey = key - assignments[0].value
          take[newKey] = pointer
        }
        result = factory.node(
          key: pointer.pointee.key,
          take: next != nil ? take.mapValues(next!.apply(on:)) : take,
          skip: factory.zero.pointer)
      } else {
        fatalError("The key to filter is lower in the MFDD. Thus, the value could never be filtered.")
      }
      
      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      for (key, value) in assignments {
        hasher.combine(key)
        hasher.combine(value)
      }
    }

    public static func == (lhs: ExclusiveFilterMarking, rhs: ExclusiveFilterMarking) -> Bool {
      lhs === rhs
    }

  }
  
  /// Allow to compute the result of a firing for post condition.
  /// Results of bindings with post arcs is added to the marking

  public final class InsertMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments inserted by this morphism.
    public let assignments: [(key: Key, value: Value)]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<InsertMarking>?

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignments.min(by: { a, b in a.key < b.key })!.key }

    init(assignments: [(key: Key, value: Value)], factory: MFDDFactory<Key, Value>) {
      assert(!assignments.isEmpty, "Sequence of assignments to insert is empty.")

      self.assignments = assignments.sorted(by: { a, b in a.key < b.key })
      
      self.next = assignments.count > 1
        ? factory.morphisms.saturate(
          factory.morphisms.insertMarking(insert: self.assignments.dropFirst()))
        : nil

      self.factory = factory
    }

    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
      // Check for trivial cases.
      if factory.isTerminal(pointer) {
        return pointer
      }
      
      // Query the cache.
      if let result = cache[pointer] {
        return result
      }

      // Apply the morphism.
      let result: MFDD.Pointer
      if pointer.pointee.key < assignments[0].key {
        result = factory.node(
          key: pointer.pointee.key,
          take: pointer.pointee.take.mapValues(apply(on:)),
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == assignments[0].key {
        var take: [Value: MFDD.Pointer] = [:]
        var newKey: Multiset<Val>
        
        for (key, p) in pointer.pointee.take {
          newKey = key + assignments[0].value
          take[newKey] = p
        }
        result = factory.node(
          key: pointer.pointee.key,
          take: next != nil ? take.mapValues(next!.apply(on:)) : take,
          skip: factory.zero.pointer)
      } else {
        fatalError("The key to filter is lower in the MFDD. Thus, the value could never be added.")
      }
      
      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      for (key, value) in assignments {
        hasher.combine(key)
        hasher.combine(value)
      }
    }

    public static func == (lhs: InsertMarking, rhs: InsertMarking) -> Bool {
      lhs === rhs
    }

  }

  
}

extension MFDDMorphismFactory
where Key: Place, Value == Multiset<Val> {
  /// Creates an _exclusive filter marking_ morphism.
  ///
  /// - Parameter assignments: A sequence with the assignments that the member must not contain.
  public func filterMarking<S>(excluding assignments: S) -> MFDD<Key, Value>.ExclusiveFilterMarking
    where S: Sequence, S.Element == (key: Key, value: Value)
  {
    return MFDD.ExclusiveFilterMarking(assignments: Array(assignments), factory: nodeFactory)
  }
  
  /// Creates an _insert  in marking_ morphism.
  ///
  /// - Parameter assignments: A sequence with the assignments to insert.
  public func insertMarking<S>(insert assignments: S) -> MFDD<Key, Value>.InsertMarking
    where S: Sequence, S.Element == (key: Key, value: Value)
  {
    return MFDD.InsertMarking(assignments: Array(assignments), factory: nodeFactory)
  }
}
