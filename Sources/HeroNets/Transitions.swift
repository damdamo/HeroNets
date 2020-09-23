import Interpreter
import AST
import Foundation

struct Transition: Hashable {
  
  typealias Place = String
  typealias Marking = [Place: [String: Int]]
  
  struct Condition: Hashable {
    let e1: String
    let e2: String
  }
  
  struct InArc: Hashable {
    let variables: [String]
    let place: Place
  }
  
  struct OutArc: Hashable {
    let expr: String
    let place: Place
  }
  
  let name: String
  let guards: [Condition]?
  let inArcs: [InArc]?
  let outArcs: [OutArc]?
    
  public func fireRandom(marking: Marking, transition: Transition, interpreter: Interpreter) -> Marking {
    return marking
  }
  
  // Return if the transition is fireable for a given marking and a given binding
  public func isFireable(marking: Marking, binding: [String: String], interpreter: Interpreter) throws -> Bool {
    if let arcs = self.inArcs {
      var markingTemp = marking
      for arc in arcs {
        for var_ in arc.variables {
          guard binding[var_] != nil else {throw HeroError.bindingOutOfRange("The binding \(binding) does not contain the variable \(var_)")}
          if let v = (markingTemp[arc.place])![binding[var_]!] {
            if v >= 1 {
              (markingTemp[arc.place])![binding[var_]!]! -= 1
            } else {
              return false
            }
          } else {
            return false
          }
        }
      }
    }
    
    // Check guards and then return the final answer
    // If checkGuards is true, then isFireable is true, otherwise it is false
    return checkGuards(binding: binding, interpreter: interpreter)
  }
  
  public func checkGuards(binding: [String: String], interpreter: Interpreter) -> Bool {
    var lhs: String = ""
    var rhs: String = ""
    if let conditions = guards {
      for condition in conditions {
        lhs = substitution(str: condition.e1, binding: binding)
        rhs = substitution(str: condition.e2, binding: binding)
        if lhs != rhs {
          print(lhs)
          print(rhs)
          let v1 = try! interpreter.eval(string: lhs)
          let v2 = try! interpreter.eval(string: rhs)
          if "\(v1)" != "\(v2)" {
            return false
          }
        }
      }
    } else {
      return true
    }
    
    return true
  }
  
  public func substitution(str: String, binding: [String: String]) -> String {
    var res: String = str
    for el in binding {
      res = res.replacingOccurrences(of: "$\(el.key)", with: "\(el.value)")
    }
    return res
  }
  
}
