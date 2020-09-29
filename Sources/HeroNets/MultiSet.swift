public struct Multiset<Element> where Element: Hashable {

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

  public func contains(_ member: Element) -> Bool {
    return storage[member] != nil
  }

  public var count: Int {
    return storage.values.reduce(0, +)
  }

  public var distinctMembers: Dictionary<Element, Int>.Values {
    return storage.values
  }

  public func occurences(of member: Element) -> Int {
    return storage[member] ?? 0
  }

  public func union(_ other: Multiset) -> Multiset {
    var result = self
    for (key, count) in other.storage {
      result.storage[key] = (result.storage[key] ?? 0) + count
    }
    return result
  }

  public func union<S>(_ sequence: S) -> Multiset where S: Sequence, S.Element == Element {
    var result = self
    for key in sequence {
      result.storage[key] = (result.storage[key] ?? 0) + 1
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
    var multiset = Multiset<Element>()
    let keys = Set(lhs.storage.keys).union(Set(rhs.storage.keys))
    for key in keys {
      multiset.insert(key, occurences: lhs.occurences(of: key) + rhs.occurences(of: key))
    }
    return multiset
  }
  
  public static func += (lhs: inout Multiset<Element>, rhs: Multiset<Element>) {
    lhs = lhs + rhs
  }
  
  public static func - (lhs: Multiset<Element>, rhs: Multiset<Element>) -> Multiset<Element> {
    var multiset = Multiset<Element>()
    var diff: Int = 0
    let keys = Set(lhs.storage.keys).union(Set(rhs.storage.keys))
    for key in keys {
      diff = lhs.occurences(of: key) - rhs.occurences(of: key)
      if diff != 0 {
        multiset.insert(key, occurences: lhs.occurences(of: key) - rhs.occurences(of: key))
      }
    }
    return multiset
  }
  
  public static func -= (lhs: inout Multiset<Element>, rhs: Multiset<Element>) {
    lhs = lhs - rhs
  }
  
  public static var zero: Multiset {
    return Multiset<Element>()
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


//extension Multiset: CustomStringConvertible {
//
//  public var description: String {
//    return "{\( map({ "\($0)" }).joined(separator: ", ") )}"
//  }
//
//}
