import DDKit
  
// TODO: Add constraint on the MFDD types for the application
extension MFDDFactory {
  
  /// `concatAndFilterInclude` (abreviate by `cfi`) is a homorphism that takes two MFDD and returns a new one.
  /// This operations is specially designed to construct a MFDD that represents all bindings for a transition
  /// Here, the goal is to concatenate variable if they do not appear in both side. (e.g.: cfi([x:1],[y:1]) -> [x:1,y:1])
  /// Otherwise, if a variable appears in both mfdd (meaning that we look at the take node of both), we only keep keys that appears in both side !
  /// Concretly, in a hero nets, when two arcs have the same variable, it allows to keep path that are only valid for both of them.
  /// Hence, when both keys are not the same, we propagete the concatenation and when it is the same key, we filter to keep only keys that appear in both side.
  /// For instance: cfi([["y": 2, "z": 3], ["y": 3, "z": 3]], [["x": 2, "z": 3], ["x": 2, "z": 4]]) => [["x": 2, "y": 2, "z": 3], ["x": 2, "y": 3, "z": 3]]
  ///
  /// - Parameters:
  ///   - lhs: The first MFDD
  ///   - rhs: The second MFDD
  /// - Returns:
  ///   The resulting MFDD with the application of the homomorphism.
  public func concatAndFilterInclude(
    _ lhs: MFDD<Key, Value>.Pointer,
    _ rhs: MFDD<Key, Value>.Pointer)
  -> MFDD<Key, Value>.Pointer {
    var cache: [[MFDD<Key, Value>.Pointer]: MFDD<Key, Value>.Pointer] = [:]
    return concatAndFilterInclude(lhs, rhs, cache: &cache)
  }
  
  /// Apply the operation using a cache. The cache memoizes operations that have been already computed, to avoid re-computation. If the same computation is applied twice, we get the result directly from the cache.
  private func concatAndFilterInclude(
    _ lhs: MFDD<Key, Value>.Pointer,
    _ rhs: MFDD<Key, Value>.Pointer,
    cache: inout [[MFDD<Key,Value>.Pointer]: MFDD<Key,Value>.Pointer])
  -> MFDD<Key, Value>.Pointer {

    let zeroPointer = self.zero.pointer
    let onePointer = self.one.pointer
    // Check for trivial cases.
    if lhs == zeroPointer || rhs == zeroPointer {
      return zeroPointer
    }
    // Query the cache.
    let cacheKey = lhs < rhs ? [lhs, rhs] : [rhs, lhs]
    if let pointer = cache[cacheKey] {
      return pointer
    }
    // Compute the intersection of `lhs` with `rhs`.
    let result: MFDD<Key, Value>.Pointer
    if lhs == onePointer {
      result = rhs
    } else if rhs == onePointer {
      result = lhs
    } else if lhs.pointee.key < rhs.pointee.key {
      result = node(
                key: lhs.pointee.key,
                take: lhs.pointee.take.mapValues({(pointer) in concatAndFilterInclude(pointer, rhs, cache: &cache)}),
                skip: zeroPointer
      )
    } else if lhs.pointee.key > rhs.pointee.key {
      result = node(
                key: rhs.pointee.key,
                take: rhs.pointee.take.mapValues({(pointer) in concatAndFilterInclude(pointer, lhs, cache: &cache)}),
                skip: zeroPointer
      )
    } else {
      let take = lhs.pointee.take
        .filter({(el) in
        if let _ = rhs.pointee.take[el.key] {
          return true
        } else {
          return false
        }
        })
        .reduce(into: [:]) { (res,el) in
          res[el.key] = concatAndFilterInclude(el.value, rhs.pointee.take[el.key]!, cache: &cache)
        }
      
      result = node(
        key: lhs.pointee.key,
        take: take,
        skip: zeroPointer
      )
    }

    cache[cacheKey] = result
    return result
  }

}
