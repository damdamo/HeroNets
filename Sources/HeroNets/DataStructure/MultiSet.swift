/// A Multiset is a structure which contains different elements (`Element`), without any order.
/// It is mainly used to represent the content of a Hero net place
/// The commonly way to represent a multiset is the following:
///
///     let m1: Multiset<String> = ["a", "a", "b", "b"]
///
/// An alternative exists to write Multisets by specifying the element and the number of occurences:
///
///     let m2: Multiset<String> = ["a":2, "b":2]
///
/// Multisets are `Comparable` and benefits of the protocol `AdditiveArithmetic` to make operations
/// such as: `m1 + m2`, `m1 - m2`, `m1 < m2`, `m1 <= m2`, `m1 > m2`, `m1 >= m2`
///
/// In addition, Multisets are a `Collection` and can be easily browsed.
public struct Multiset<Element>: Hashable where Element: Hashable {

  public init() {
    self.storage = [:]
  }

  private var storage: [Element: Int]

  @discardableResult
  public mutating func insert(_ newMember: Element, occurences: Int = 1) -> Int {
    let n = storage[newMember] ?? 0
    storage[newMember] = n + occurences
    return n + occurences
  }

  public mutating func remove(_ member: Element, occurences: Int = 1) {
    guard let n = storage[member]
      else { return }

    storage[member] = occurences < n
      ? n - occurences
      : nil
  }
  
  public mutating func removeAll(_ member: Element) {
    storage[member] = nil
  }

  public func contains(_ member: Element) -> Bool {
    return storage[member] != nil
  }

  public var count: Int {
    return storage.values.reduce(0, +)
  }

  public var distinctMembers: Dictionary<Element, Int>.Keys {
    return storage.keys
  }

  public func occurences(of member: Element) -> Int {
    return storage[member] ?? 0
  }

  public func union(_ other: Multiset) -> Multiset {
    var result = self
    for (key, count) in other.storage {
      result.storage[key] = Swift.max(result.storage[key] ?? 0, count)
    }
    return result
  }

  public func subtract(_ other: Multiset) -> Multiset {
    var result = self
    for (key, count) in other.storage {
      result.remove(key, occurences: count)
    }
    return result
  }

  public func subtract<S>(_ sequence: S) -> Multiset where S: Sequence, S.Element == Element {
    var result = self
    for key in sequence {
      result.remove(key)
    }
    return result
  }
  
  public func multisetToArray() -> Array<Element> {
    var arr: Array<Element> = []
    for (key,value) in storage {
      for _ in 0 ... value-1 {
        arr.append(key)
      }
    }
    return arr
  }

}

extension Multiset: Equatable {

}

extension Multiset: Collection {

  public struct Index: Comparable {

    fileprivate let key: Dictionary<Element, Int>.Index
    fileprivate let count: Int

    public static func < (lhs: Index, rhs: Index) -> Bool {
      return lhs.key == rhs.key
        ? lhs.count < rhs.count
        : lhs.key < rhs.key
    }

  }

  public var startIndex: Index {
    return Index(key: storage.startIndex, count: 1)
  }

  public var endIndex: Index {
    return Index(key: storage.endIndex, count: 1)
  }

  public func index(after i: Index) -> Index {
    guard i.key < storage.endIndex
      else { return endIndex }
    if i.count < storage[i.key].value {
      return Index(key: i.key, count: i.count + 1)
    } else {
      return Index(key: storage.index(after: i.key), count: 1)
    }
  }

  public subscript(i: Index) -> Element {
    return storage[i.key].key
  }

}

extension Multiset: ExpressibleByArrayLiteral {

  public init(arrayLiteral elements: Element...) {
    storage = [:]
    for element in elements {
      storage[element] = (storage[element] ?? 0) + 1
    }
  }

}

extension Multiset: Comparable {
  public static func < (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Bool {
    guard rhs.storage.count != 0 else {
      return false
    }
    
    for (k,v) in lhs.storage {
      if v >= rhs.occurences(of: k) {
        return false
      }
    }
    return true
  }
  
  public static func > (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Bool {
    guard lhs.storage.count != 0 else {
      return false
    }
    
    for (k,v) in rhs.storage {
      if lhs.occurences(of: k) <= v {
        return false
      }
    }
    return true
  }
  
  public static func <= (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Bool {
    guard rhs.storage.count != 0 else {
      if lhs.storage.count == 0 {
        return true
      } else {
        return false
      }
    }
    
    for (k,v) in lhs.storage {
      if v > rhs.occurences(of: k) {
        return false
      }
    }
    return true
  }
  
  public static func >= (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Bool {
    guard lhs.storage.count != 0 else {
      if rhs.storage.count == 0 {
        return true
      } else {
        return false
      }
    }
    
    for (k,v) in rhs.storage {
      if lhs.occurences(of: k) < v {
        return false
      }
    }
    return true
  }
  
}
  
extension Multiset: AdditiveArithmetic {
  public static func + (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Multiset<Element> {
    var result = lhs
    for (key, count) in rhs.storage {
      result.storage[key] = (result.storage[key] ?? 0) + count
    }
    return result
  }
  
  public static func += (lhs: inout Multiset<Element>, rhs: Multiset<Element>) {
    lhs = lhs + rhs
  }
  
  public static func - (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Multiset<Element> {
    return lhs.subtract(rhs)
  }
  
  public static func -= (lhs: inout Multiset<Element>, rhs: Multiset<Element>) {
    lhs = lhs - rhs
  }
  
  public static var zero: Multiset {
    return Multiset<Element>()
  }
  
  public func intersection(_ rhs: Multiset<Element>) -> Multiset<Element> {
    var newMultiset: Multiset<Element> = []
    for (key, nb) in self.storage {
      if let v = rhs.storage[key] {
        newMultiset.insert(key, occurences: Swift.min(nb, v))
      }
    }
    return newMultiset
  }
  
  public func intersectionUpperBound(_ rhs: Multiset<Element>) -> Multiset<Element> {
    var newMultiset: Multiset<Element> = []
    for (key, nb) in self.storage {
      if let v = rhs.storage[key] {
        newMultiset.insert(key, occurences: Swift.max(nb, v))
      }
    }
    return newMultiset
  }

  // Keep elements belong to rhs
  public func filterInclude(_ rhs: Multiset<Element>) -> Multiset<Element> {
    var res = Multiset()
    for el in self {
      if rhs.contains(el) {
        res.insert(el)
      }
    }
    return res
  }
}

extension Multiset: ExpressibleByDictionaryLiteral {
  
  public typealias Key = Element
  public typealias Value = Int
  
  public init(dictionaryLiteral elements: (Element, Int)...) {
    self.storage = [:]
    for (el,i) in elements {
      self.insert(el, occurences: i)
    }
  }
}


extension Multiset: CustomStringConvertible {

  public var description: String {
    return "\(storage)"
  }
}
