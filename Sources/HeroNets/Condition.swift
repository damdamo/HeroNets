public struct Condition: Hashable {
  let e1: String
  let e2: String
  
  public init(_ e1: String, _ e2: String) {
    self.e1 = e1
    self.e2 = e2
  }
}

//extension Condition: ExpressibleByArrayLiteral {
//  public init(arrayLiteral elements: String...) {
//    guard elements.count == 2 else {
//      throw Error.self
//    }
//  }
//  
//  public typealias ArrayLiteralElement = String
//  
//}
