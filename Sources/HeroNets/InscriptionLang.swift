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
