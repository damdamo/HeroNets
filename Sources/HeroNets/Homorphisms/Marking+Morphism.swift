import DDKit

extension MFDD
where Key: Place, Key.Content == Multiset<String>, Value == Pair<String,Int> {

  /// Allow to compute the result of a firing for pre condition.
  /// Results of bindings with pre arcs is removed from the marking
  public final class ExclusiveFilterMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments filtered by this morphism.
    public let assignments: [(key: Key, values: [Value])]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<ExclusiveFilterMarking>?

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignments.min(by: { a, b in a.key < b.key })!.key }

    init(assignments: [(key: Key, values: [Value])], factory: MFDDFactory<Key, Value>) {
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
      guard !factory.isTerminal(pointer)
        else { return pointer }

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
          skip: apply(on: pointer.pointee.skip))
      } else if pointer.pointee.key == assignments[0].key {
        var take: [Value: MFDD.Pointer] = pointer.pointee.take
        
        // The goal of this step is to find the key in the assignement in the mfdd, and to subtract the number of element in the assignement by the current name in the mfdd.
        // E.g.: Suppose the following mfdd: (key: p0, values: [(key: Pair("42", 2), value: mfddPointer), (key: Pair("10", 1), value: anotherMfddPointer)])
        // If we have to remove an element of Pair("42",1), we find the key Pair("42",2) and we subtract with the right value of first assignement -> Pair("42", 2-1) -> Pair("42", 1)
        for value in assignments[0].values {
          let pairTemp = take.first(where: {(k,v) in
            return k.l == value.l
          })
          let newKey = Pair(pairTemp!.key.l, pairTemp!.key.r - value.r)
          if newKey.r > 0 {
            take[newKey] = pairTemp!.value
          }
          take[pairTemp!.key] = nil
        }

        if !take.isEmpty {
          result = factory.node(
            key: pointer.pointee.key,
            take: next != nil ? take.mapValues(next!.apply(on:)) : take,
            skip: next?.apply(on: pointer.pointee.skip) ?? pointer.pointee.skip)
        } else {
//          result = factory.node(
//            key: pointer.pointee.key,
//            take: [:],
//            skip: pointer.pointee.take.first!.value)
          result = factory.node(
            key: pointer.pointee.key,
            take: [:],
            skip: next != nil ? pointer.pointee.take.mapValues(next!.apply(on:)).first!.value : pointer.pointee.take.first!.value)
        }
      } else {
        result = next?.apply(on: pointer) ?? pointer
      }

      cache[pointer] = result
      return result
    }

    public func hash(into hasher: inout Hasher) {
      for (key, values) in assignments {
        hasher.combine(key)
        hasher.combine(values)
      }
    }

    public static func == (lhs: ExclusiveFilterMarking, rhs: ExclusiveFilterMarking) -> Bool {
      lhs === rhs
    }

  }
  
  /// Allow to compute the result of a firing for post condition.
  /// Results of bindings with post arcs is added to the marking
  public final class InsertValueInMarking: Morphism, MFDDSaturable {

    public typealias DD = MFDD

    /// The assignments inserted by this morphism.
    public let assignments: [(key: Key, values: [Value])]

    /// The next morphism to apply once the first assignment has been processed.
    private var next: SaturatedMorphism<InsertValueInMarking>?

    /// The factory that creates the nodes handled by this morphism.
    public unowned let factory: MFDDFactory<Key, Value>

    /// The morphism's cache.
    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]

    public var lowestRelevantKey: Key { assignments.min(by: { a, b in a.key < b.key })!.key }

    init(assignments: [(key: Key, values: [Value])], factory: MFDDFactory<Key, Value>) {
      assert(!assignments.isEmpty, "Sequence of assignments to insert is empty.")

      self.assignments = assignments.sorted(by: { a, b in a.key < b.key })
      
      self.next = assignments.count > 1
        ? factory.morphisms.saturate(
          factory.morphisms.insertValueInMarking(insert: self.assignments.dropFirst()))
        : nil

      self.factory = factory
    }

    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
      // Check for trivial cases.
      guard pointer != factory.zero.pointer
        else { return pointer }

      // Query the cache.
      if let result = cache[pointer] {
        return result
      }

      // Apply the morphism.
      let result: MFDD.Pointer
      if pointer == factory.one.pointer {
        var encode = factory.encode(family: [[:]])
        for (k,v) in assignments {
          for el in v {
            let morphism = factory.morphisms.insert(assignments: [(key: k, value: el)])
            encode = morphism.apply(on: encode)
          }
        }
        result = encode.pointer
      } else if pointer.pointee.key < assignments[0].key {
          result = factory.node(
            key: pointer.pointee.key,
            take: pointer.pointee.take.mapValues(apply(on:)),
            skip: apply(on: pointer.pointee.skip))
      } else if pointer.pointee.key == assignments[0].key {
        var take = pointer.pointee.take

        // If take is not empty, we look at values already contain in take and added to the current result.
        // e.g.: take ~= [("42",1): pointer], assignements[0] = [("42",2)] --> newTake = [("42",3): pointer]
        if !pointer.pointee.take.isEmpty {
          for value in assignments[0].values {
            if let tail = pointer.pointee.take.first(where: {(k,v) in
              k.l == value.l
            }) {
              let newPair = Pair(value.l, value.r + tail.key.r)
              take[newPair] = tail.value
              take[tail.key] = nil
            } else if !take.isEmpty {
              take[value] = pointer.pointee.take.first!.value
            } else {
              take[value] = pointer.pointee.skip
            }
          }
        // If it is empty, we can simply add values in assignements
        } else {
          for value in assignments[0].values {
            if let tail = pointer.pointee.take[value] {
              take[value] = factory.union(tail, pointer.pointee.skip)
            } else {
              take[value] = take.values.reduce(pointer.pointee.skip, factory.union)
            }
          }
        }
        result = factory.node(
          key: pointer.pointee.key,
          take: next != nil ? take.mapValues(next!.apply(on:)) : take,
          skip: factory.zero.pointer)
      // If pointer.pointee.key > assignments[0].key
      } else {
        var take: [Pair<String, Int> : MFDD<Key, Pair<String, Int>>.Pointer] = [:]
        for value in assignments[0].values {
          take[value] = next?.apply(on: pointer) ?? pointer
        }
        result = factory.node(
          key: assignments[0].key,
          take: take,
          skip: factory.zero.pointer)
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

    public static func == (lhs: InsertValueInMarking, rhs: InsertValueInMarking) -> Bool {
      lhs === rhs
    }

  }

  
}

extension MFDDMorphismFactory
where Key: Place, Key.Content == Multiset<String>, Value == Pair<String,Int> {
  /// Creates an _exclusive filter marking_ morphism.
  ///
  /// - Parameter assignments: A sequence with the assignments that the member must not contain.
  public func filterMarking<S>(excluding assignments: S) -> MFDD<Key, Value>.ExclusiveFilterMarking
    where S: Sequence, S.Element == (key: Key, values: [Value])
  {
    return MFDD.ExclusiveFilterMarking(assignments: Array(assignments), factory: nodeFactory)
  }
  
  /// Creates an _insert  in marking_ morphism.
  ///
  /// - Parameter assignments: A sequence with the assignments to insert.
  public func insertValueInMarking<S>(insert assignments: S) -> MFDD<Key, Value>.InsertValueInMarking
    where S: Sequence, S.Element == (key: Key, values: [Value])
  {
    return MFDD.InsertValueInMarking(assignments: Array(assignments), factory: nodeFactory)
  }
}
