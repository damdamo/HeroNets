struct Pair<T>: Hashable where T: Hashable {
  
  let l:  T
  let r: T
  
  public init (_ l: T, _ r: T) {
    self.l = l
    self.r = r
  }
  
  static func == (lhs: Pair<T>, rhs: Pair<T>) -> Bool {
    return lhs.l == rhs.l && lhs.r == rhs.r
  }
}

extension Pair: CustomStringConvertible {
  var description: String {
    return "(\(self.l),\(self.r))"
  }
}
