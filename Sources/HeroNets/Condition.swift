/// Declare a condition between two strings
public struct Condition: Hashable {
  let e1: String
  let e2: String
  
  public init(_ e1: String, _ e2: String) {
    self.e1 = e1
    self.e2 = e2
  }
}
