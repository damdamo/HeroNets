/// A Key is a requires structure to satisfay MFDD
/// A key needs to  be comparable w.r.t the MFDD (k1 < k2 < ...) and hashable
/// The order key is not important but need to be created and constant
/// The order on String cannot be used because of the name
/// that are chosen by the creator of the Hero nets.
/// The Key contains the name (variable name)
/// and a list of pairs where each tuple represents a relation of comparison
/// between both values.
/// Pair(l,r) => l < r
public struct Key {

  let label: Label
  let couple: [Pair<Label>]
  
  public init (label: Label, couple: [Pair<Label>]) {
    self.label = label
    self.couple = couple
  }
}


extension Key: Comparable &  Hashable {
  public static func == (lhs: Key, rhs: Key) -> Bool {
    return lhs.label == rhs.label
  }
  
  public static func < (lhs: Key, rhs: Key) -> Bool {
    return lhs.couple.contains (where: { pair in
      return (pair.l == lhs.label && pair.r == rhs.label)
    })
  }
}


extension Key: CustomStringConvertible {
  public var description: String {
    return "\(self.label)"
  }
}


public struct Label {
  let name: String
  let n: Int
}

extension Label: Hashable {}

extension Label: CustomStringConvertible {
  public var description: String {
    return "\(self.name)_\(self.n)"
  }
}
