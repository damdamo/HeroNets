public struct Pair<T,U>: Hashable where T: Hashable, U: Hashable {
  
  var l:  T
  var r: U
  
  public init (_ l: T, _ r: U) {
    self.l = l
    self.r = r
  }
  
}

extension Pair: CustomStringConvertible {
  public var description: String {
    return "(\(self.l),\(self.r))"
  }
}
