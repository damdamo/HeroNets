import DDKit

extension MFDD
where Key: Place, Value == Multiset<Val> {

  /// Allow to compute the result of a firing for pre condition.
  /// Results of bindings with pre arcs is removed from the marking
  public final class RemoveValuesInMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments filtered by this morphism.
    public let assignments: [(key: Key, value: Value)]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<RemoveValuesInMarking>?

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
          factory.morphisms.removeValuesInMarking(excluding: self.assignments.dropFirst()))
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
        fatalError("One of the key/values to remove is too lower in the MFDD. Thus, one of the values could never be removed.")
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

    public static func == (lhs: RemoveValuesInMarking, rhs: RemoveValuesInMarking) -> Bool {
      lhs === rhs
    }

  }
  
  /// Allow to compute the result of a firing for post condition.
  /// Results of bindings with post arcs is added to the marking
  public final class InsertValuesInMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments inserted by this morphism.
    public let assignments: [(key: Key, value: Value)]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<InsertValuesInMarking>?

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
          factory.morphisms.insertValuesInMarking(insert: self.assignments.dropFirst()))
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
        fatalError("One of the key/values to insert is too lower in the MFDD. Thus, one of the values could never be inserted.")
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

    public static func == (lhs: InsertValuesInMarking, rhs: InsertValuesInMarking) -> Bool {
      lhs === rhs
    }

  }


  /// Remove a value from all multisets for a specific place
  public final class RemoveValueInMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments filtered by this morphism.
    public let assignment: (key: Key, value: Value.Key)

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignment.key }

    init(assignment: (key: Key, value: Value.Key), factory: MFDDFactory<Key, Value>) {
      self.assignment = assignment
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
      if pointer.pointee.key < assignment.key {
        result = factory.node(
          key: pointer.pointee.key,
          take: pointer.pointee.take.mapValues(apply(on:)),
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == assignment.key {
        var take: [Value: MFDD.Pointer] = [:]
        var newKey: Multiset<Val>
        
        for (key, pointer) in pointer.pointee.take {
          newKey = key
          newKey.remove(assignment.value)
          take[newKey] = pointer
        }
        
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else {
        fatalError("The key/value to remove is too lower in the MFDD. Thus, the value could never be removed.")
      }
      
      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(assignment.key)
      hasher.combine(assignment.value)
    }

    public static func == (lhs: RemoveValueInMarking, rhs: RemoveValueInMarking) -> Bool {
      lhs === rhs
    }

  }
  
  /// Add a value in all multiset for a specific place
  public final class InsertValueInMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments inserted by this morphism.
    public let assignment: (key: Key, value: Value.Key)

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignment.key }

    init(assignment: (key: Key, value: Value.Key), factory: MFDDFactory<Key, Value>) {
      self.assignment = assignment
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
      if pointer.pointee.key < assignment.key {
        result = factory.node(
          key: pointer.pointee.key,
          take: pointer.pointee.take.mapValues(apply(on:)),
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == assignment.key {
        var take: [Value: MFDD.Pointer] = [:]
        var newKey: Multiset<Val>
        
        for (key, pointer) in pointer.pointee.take {
          newKey = key
          newKey.insert(assignment.value)
          take[newKey] = pointer
        }
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else {
        fatalError("The key/value to insert is too lower in the MFDD. Thus, the value could never be inserted.")
      }
      
      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(assignment.key)
      hasher.combine(assignment.value)
    }

    public static func == (lhs: InsertValueInMarking, rhs: InsertValueInMarking) -> Bool {
      lhs === rhs
    }
  }
  
  /// Keep marking where a place contains a specific value in the multiset
  public final class filterMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments inserted by this morphism.
    public let assignment: (key: Key, value: Value.Key)

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignment.key }

    init(assignment: (key: Key, value: Value.Key), factory: MFDDFactory<Key, Value>) {
      self.assignment = assignment
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
      if pointer.pointee.key < assignment.key {
        result = factory.node(
          key: pointer.pointee.key,
          take: pointer.pointee.take.mapValues(apply(on:)),
          skip: factory.zero.pointer)
      } else if pointer.pointee.key == assignment.key {
        var take: [Value: MFDD.Pointer] = [:]
        
        for (key, pointer) in pointer.pointee.take {
          if key.contains(assignment.value) {
            take[key] = pointer
          }
        }
        result = factory.node(
          key: pointer.pointee.key,
          take: take,
          skip: factory.zero.pointer)
      } else {
        fatalError("The key to filter is lower in the MFDD. Thus, the value could never be filtered.")
      }
      
      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(assignment.key)
      hasher.combine(assignment.value)
    }

    public static func == (lhs: filterMarking, rhs: filterMarking) -> Bool {
      lhs === rhs
    }
  }

}


extension MFDDMorphismFactory
where Key: Place, Value == Multiset<Val> {
  /// Creates a morphism to remove multiple elements at a time
  ///
  /// - Parameter assignments: A sequence with the assignments that the member must not contain.
  public func removeValuesInMarking<S>(excluding assignments: S) -> MFDD<Key, Value>.RemoveValuesInMarking
  where S: Sequence, S.Element == (key: Key, value: Value)
  {
    return MFDD.RemoveValuesInMarking(assignments: Array(assignments), factory: nodeFactory)
  }
  
  /// Creates a morphism to insert multiple elements at a time
  ///
  /// - Parameter assignments: A sequence with the assignments to insert.
  public func insertValuesInMarking<S>(insert assignments: S) -> MFDD<Key, Value>.InsertValuesInMarking
  where S: Sequence, S.Element == (key: Key, value: Value)
  {
    return MFDD.InsertValuesInMarking(assignments: Array(assignments), factory: nodeFactory)
  }
  
  /// Creates a morphism to remove an element in a place
  public func removeValueInMarking(assignment: (key: Key, value: Value.Key)) -> MFDD<Key,Value>.RemoveValueInMarking
  {
    return MFDD.RemoveValueInMarking(assignment: assignment, factory: nodeFactory)
  }
  
  /// Creates a morphism to insert an element in a place
  public func insertValueInMarking(assignment: (key: Key, value: Value.Key)) -> MFDD<Key, Value>.InsertValueInMarking
  {
    return MFDD.InsertValueInMarking(assignment: assignment, factory: nodeFactory)
  }
  
  /// Creates a morphism to filter marking which not include the assignement, i.e. where multiset does not include a specific value.
  public func filterMarking(include assignment: (key: Key, value: Value.Key)) -> MFDD<Key, Value>.filterMarking {
    return MFDD.filterMarking(assignment: assignment, factory: nodeFactory)
  }
}
