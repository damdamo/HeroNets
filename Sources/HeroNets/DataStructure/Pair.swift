public struct Pair<T>: Hashable where T: Hashable {
  
  var l:  T
  var r: T
  
  public init (_ l: T, _ r: T) {
    self.l = l
    self.r = r
  }
  
  public static func == (lhs: Pair<T>, rhs: Pair<T>) -> Bool {
    return lhs.l == rhs.l && lhs.r == rhs.r
  }
}

extension Pair: CustomStringConvertible {
  public var description: String {
    return "(\(self.l),\(self.r))"
  }
}
