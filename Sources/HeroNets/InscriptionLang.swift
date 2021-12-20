public enum ILang: Hashable {
  case `var`(String)
  case exp(String)
  case val(Val)
}

public enum Val: Hashable {
  case cst(String)
  case btk
  
  public static func arrayStrToMultisetVal(_ arr: [String]) -> Multiset<Val> {
    var res: Multiset<Val> = []
    for el in arr {
      res.insert(.cst(el))
    }
    return res
  }
}

extension Val: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    if value == "btk" {
      self = .btk
    } else {
      self = .cst(value)
    }
  }
}

extension ILang: CustomStringConvertible {
  public var description: String {
    switch self {
    case .var(let v):
      return v
    case .exp(let e):
      return e
    case .val(let val):
      return val.description
    }
  }
}

extension Val: CustomStringConvertible {
  public var description: String {
    switch self {
    case .cst(let c):
      return c
    case .btk:
      return "⚫️"
    }
  }
}
