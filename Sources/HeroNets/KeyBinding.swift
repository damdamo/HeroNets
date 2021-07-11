/// A Key is a requires structure to satisfay MFDD
/// A key needs to  be comparable w.r.t the MFDD (k1 < k2 < ...) and hashable
/// The order key is not important but need to be created and constant
/// The order on String cannot be used because of the name
/// that are chosen by the creator of the Hero nets.
/// The Key contains the name (variable name)
/// and a list of pairs where each tuple represents a relation of comparison
/// between both values.
/// Pair(l,r) => l < r
struct Key: Comparable &  Hashable {

  public init (name: String, couple: [Pair<String>]) {
    self.name = name
    self.couple = couple
  }
  
  static func == (lhs: Key, rhs: Key) -> Bool {
    return lhs.name == rhs.name
  }

  let name: String
  let couple: [Pair<String>]
  
  static func < (lhs: Key, rhs: Key) -> Bool {
    return lhs.couple.contains (where: { pair in
      return (pair.l == lhs.name && pair.r == rhs.name)
    })
  }
}

extension Key: CustomStringConvertible {
  var description: String {
    return "\(self.name)"
  }
}
