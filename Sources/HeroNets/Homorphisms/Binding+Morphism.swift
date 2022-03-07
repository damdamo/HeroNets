//import DDKit
//
//extension MFDD
//where Key == String, Value == Val {
//  public final class Bindings: Morphism, MFDDSaturable {
//
//    public typealias DD = MFDD
//    public typealias Var = String
//
//    /// The assignments filtered by this morphism.
//    public let assignments: [(key: Place, value: [Var])]
//
//    /// The next morphism to apply once the first assignment has been processed.
//    private var next: SaturatedMorphism<RemoveValuesInMarking>?
//
//    /// The factory that creates the nodes handled by this morphism.
//    public unowned let factory: MFDDFactory<Key, Value>
//
//    /// The morphism's cache.
//    private var cache: [MFDD.Pointer: MFDD.Pointer] = [:]
//
//    public var lowestRelevantKey: Key { assignments.min(by: { a, b in a.key < b.key })!.key }
//
//    init(assignments: [(key: Key, value: Value)], factory: MFDDFactory<Key, Value>) {
//      assert(!assignments.isEmpty, "Sequence of assignments to filter is empty.")
//
//      self.assignments = assignments.sorted(by: { a, b in a.key < b.key })
//      self.next = assignments.count > 1
//        ? factory.morphisms.saturate(
//          factory.morphisms.removeValuesInMarking(excluding: self.assignments.dropFirst()))
//        : nil
//
//      self.factory = factory
//    }
//
//    public func apply(on pointer: MFDD.Pointer) -> MFDD.Pointer {
//      // Check for trivial cases.
//      if factory.isTerminal(pointer) {
//        return pointer
//      }
//
//      // Query the cache.
//      if let result = cache[pointer] {
//        return result
//      }
//
//      // Apply the morphism.
//      let result: MFDD.Pointer
//      if pointer.pointee.key < assignments[0].key {
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: pointer.pointee.take.mapValues(apply(on:)),
//          skip: factory.zero.pointer)
//      } else if pointer.pointee.key == assignments[0].key {
//        var take: [Value: MFDD.Pointer] = [:]
//        var newKey: Multiset<Val>
//
//        for (key, pointer) in pointer.pointee.take {
//          newKey = key - assignments[0].value
//          take[newKey] = pointer
//        }
//
//        result = factory.node(
//          key: pointer.pointee.key,
//          take: next != nil ? take.mapValues(next!.apply(on:)) : take,
//          skip: factory.zero.pointer)
//      } else {
//        fatalError("One of the key/values to remove is too lower in the MFDD. Thus, one of the values could never be removed.")
//      }
//
//      cache[pointer] = result
//      return result
//    }
//
//    public func hash(into hasher: inout Hasher) {
//      for (key, value) in assignments {
//        hasher.combine(key)
//        hasher.combine(value)
//      }
//    }
//
//    public static func == (lhs: Bindings, rhs: Bindings) -> Bool {
//      lhs === rhs
//    }
//
//  }
//}
//
//
////extension MFDDMorphismFactory
////where Key: Place, Value == Multiset<Val> {
////  /// Creates a morphism to filter marking which not include the assignement, i.e. where multiset does not include a specific value.
////  public func bindings(assignment: (key: Key, value: Value.Key)) -> MFDD<Key, Value>.Bindings {
////    return MFDD.bindings(assignment: assignment, factory: nodeFactory)
////  }
////}
