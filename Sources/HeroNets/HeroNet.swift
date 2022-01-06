import Interpreter

/// A Hero net.
///
/// `HeroNet` is a generic type, accepting two types representing the set of places and the set
/// of transitions that structurally compose the model. Both should conform to `CaseIterable`,
/// which guarantees that the set of places (resp. transitions) is bounded, and known statically.
/// It must conform to `Hashable` to be used as a key in dictionnary.
/// The following example illustrates how to declare the places and transition of a simple Petri
/// net representing an on/off switch:
///
///     enum P: Place {
///       typealias Content = Multiset<String>
///       case p1, p2
///     }
///
///     enum T: Transition {
///       case t1
///     }
///
/// Hero net instances are created by providing the list of the preconditions and postconditions
/// that compose them, guards of each transition and  an interpreter to evaluate the term inside the net.
/// Preconditions and postconditions should be provided in the form of arc descriptions (i.e. instances of
/// `ArcDescription`) and fed directly to the Petri net's initializer.
/// Guards are provided by a list of condition for each transition.
/// Interpreter and its module has to be loaded before to initialize the net.
///
/// The following example shows
/// how to create an instance of a Hero net with above Place and Transition:
///
///     let module: String = """
///       func add(_ x: Int, _ y: Int) -> Int ::
///          x + y
///     """
///
///    var interpreter = Interpreter()
///    try! interpreter.loadModule(fromString: module)
///
///    let model = HeroNet<P, T>(
///      .pre(from: .p1, to: .t1, labeled: ["x", "y"]),
///      .post(from: .t1, to: .p2, labeled: ["$x+$y"]),
///      guards: [.t1: [Condition("$x","$y")]],
///      interpreter: interpreter
///    )
///
///
/// Hero net instances only represent the structual part of the corresponding model, meaning that
/// markings should be stored externally. They can however be used to compute the marking resulting
/// from the firing of a particular transition, using the method `fire(transition:from:with:)`. The
/// following example illustrates this method's usage:
///
///     let marking = Marking<P>([.p1: ["1", "2", "2", "3"], .p2: []])
///
///     if let marking = model.fire(transition: .t1, from: marking, with: ["$x": "2", "$y": "2"]) {
///       print(marking)
///     }
///     // Prints "[.p1: ["1", "3"], .p2: ["4"]]"
///
public struct HeroNet<PlaceType, TransitionType>
where PlaceType: Place, PlaceType.Content == Multiset<Val>, TransitionType: Transition
{
  
  /// How variables are represented (e.g.: Using String)
  public typealias Var = String
  /// A multiset of value, typically content inside a place
  public typealias MultisetVal = Multiset<Val>
  /// Content on an arc, multiset of the inscription language
  public typealias ArcLabel = Multiset<ILang>
  /// A Pair of the inscription language
  public typealias Guard = Pair<ILang, ILang>
  
  /// The description of an arc.
  public struct ArcDescription {

    /// The place to which the arc is connected.
    fileprivate let place: PlaceType

    /// The transition to which the arc is connected.
    fileprivate let transition: TransitionType

    /// The arc's label.
    fileprivate let labels: ArcLabel

    /// The arc's direction.
    fileprivate let isPre: Bool

    private init(place: PlaceType, transition: TransitionType, labels: Multiset<ILang>, isPre: Bool) {
      self.place = place
      self.transition = transition
      self.labels = labels
      self.isPre = isPre
    }

    /// Creates the description of a precondition arc.
    ///
    /// - Parameters:
    ///   - place: The place from which the arc comes.
    ///   - transition: The transition to which the arc goes.
    ///   - labels: The arc's labels with variables. (e.g.: ["x","y"])
    public static func pre(
      from place: PlaceType,
      to transition: TransitionType,
      labeled labels: Multiset<ILang>)
      -> ArcDescription
    {
      return ArcDescription(place: place, transition: transition, labels: labels, isPre: true)
    }

    /// Creates the description of a postcondition arc.
    ///
    /// - Parameters:
    ///   - transition: The transition from which the arc comes.
    ///   - place: The place to which the arc goes.
    ///   - labels: The arc's labels with terms. (e.g.: ["x+3","y+2"])
    public static func post(
      from transition: TransitionType,
      to place: PlaceType,
      labeled labels: Multiset<ILang>)
      -> ArcDescription
    {
      return ArcDescription(place: place, transition: transition, labels: labels, isPre: false)
    }

  }

  /// This net's input matrix.
  public let input: [TransitionType: [PlaceType: ArcLabel]]

  /// This net's output matrix.
  public let output: [TransitionType: [PlaceType: ArcLabel]]
  
  /// Guards for transitions.
  public let guards: TotalMap<TransitionType, [Guard]?>
  
  /// Interpreter needed to evaluate Hero terms.
  public var interpreter: Interpreter
  
  /// Code for the interpreter
//  public let module: String


  /// Initializes a Petri net with a sequence describing its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A sequence containing the descriptions of the Petri net's arcs.
  ///   - guards: Conditions to fire a transition
  ///   - interpreter: Interpreter needed to evaluate terms
  public init<Arcs>(_ arcs: Arcs, guards: [TransitionType: [Guard]?], interpreter: Interpreter) where Arcs: Sequence, Arcs.Element == ArcDescription {
    var pre: [TransitionType: [PlaceType: ArcLabel]] = [:]
    var post: [TransitionType: [PlaceType: ArcLabel]] = [:]

    for arc in arcs {
      if arc.isPre {
        HeroNet.add(arc: arc, to: &pre)
      } else {
        HeroNet.add(arc: arc, to: &post)
      }
    }

    self.input = pre
    self.output = post
    self.guards = TotalMap(guards)
    
    var interpreter = interpreter
    let module = """
      func id(_ x: Int) -> Int ::
        x
    """
    try! interpreter.loadModule(fromString: module)
    self.interpreter = interpreter
  }

  /// Initializes a Petri net with descriptions of its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A variadic argument representing the descriptions of the Petri net's arcs.
  public init(_ arcs: ArcDescription..., guards: [TransitionType: [Guard]?], interpreter: Interpreter) {
    self.init(arcs, guards: guards, interpreter: interpreter)
  }
    
  /// Initializes a Petri net with all components.
  init(
    input: [TransitionType: [PlaceType: ArcLabel]],
    output: [TransitionType: [PlaceType: ArcLabel]],
    guards: TotalMap<TransitionType, [Guard]?>,
    interpreter: Interpreter
  ) {
    self.input = input
    self.output = output
    self.guards = guards
    self.interpreter = interpreter
  }

  /// Computes the marking resulting from the firing of the given transition, from the given
  /// marking, assuming the former is fireable.
  ///
  /// - Parameters:
  ///   - transition: The transition to fire.
  ///   - from: The marking that is used to fire the transition
  ///   - with: The binding that bound variables on the arcs
  /// - Returns:
  ///   The marking that results from the firing of the given transition, or
  ///   `nil` if it is not fireable.
  public func fire(
    transition: TransitionType,
    from marking: Marking<PlaceType>,
    with binding: [Var: Val])
  -> Marking<PlaceType>? {
    
    guard isFireable(transition: transition, from: marking, with: binding) else {
      return nil
    }
    
    var inputMarking: [PlaceType: PlaceType.Content] = [:]
    var outputMarking: [PlaceType: PlaceType.Content] = [:]
      
    for place in PlaceType.allCases {
      inputMarking[place] = [:]
      outputMarking[place] = [:]
    }
    
    // Compute input marking
    if let pre = input[transition] {
      var multiset: MultisetVal = [:]
      // In the case of pre, expressions is just a list of labels
      for (place, labels) in pre {
        for label in labels {
          switch label {
          case .var(let v):
            multiset.insert(binding[v]!)
          case .val(let val):
            multiset.insert(val)
          case .exp(_):
            fatalError("No expressions allow in binding")
          }
        }
        // Create a multiset for each place of input arcs of the transition
        inputMarking[place] = multiset
        multiset = [:]
      }
    }
    // Interpreter evaluate terms which are expressed by String
    var valOutput: Val
    var exprSubs: ILang
    // Compute result of input arcs
    if let post = output[transition] {
      var multiset: MultisetVal = [:]
      // In the case of post, expressions is a list of strings containing labels
      for (place, labels) in post {
        for label in labels {
          switch label {
          case .var(let v):
            multiset.insert(binding[v]!)
          case .val(let val):
            multiset.insert(val)
          case .exp(let e):
            exprSubs = bindVariables(expr: .exp(e), binding: binding)
            valOutput = eval(exprSubs)
            // In the case or we get the signature of a function, we just return the function name
            switch valOutput {
            case .cst(let c):
              if c.contains("function") {
                switch exprSubs {
                case .exp(let e):
                  multiset.insert(.cst(e))
                default:
                  fatalError("Not possible")
                }
              } else {
                multiset.insert(.cst(c))
              }
            case .btk:
              multiset.insert(.btk)
            }
          }
        }
        // Create a multiset for each place of output arcs of the transition
        outputMarking[place] = multiset
        multiset = [:]
      }
    }
    
    // Return final result
    return marking - Marking<PlaceType>(inputMarking) + Marking<PlaceType>(outputMarking)
    
  }
  
  /// Check the fireability of a transition for a given marking
  public func isFireable(
    transition: TransitionType,
    from marking: Marking<PlaceType>,
    with binding: [Var: Val])
  -> Bool {
    
    var multiset: Multiset<Val>
    if let pre = input[transition] {
      for (place, labels) in pre {
        multiset = [:]
        for label in labels {
          switch label {
          case .var(let v):
            if let vSubs = binding[v] {
              multiset.insert(vSubs)
            } else {
              return false
            }
          case .val(let val):
            multiset.insert(val)
          default:
            fatalError("No expressions allow in binding")
          }
        }
        guard multiset <= marking[place] else {
          return false
        }
      }
    }
    
    if checkGuards(transition: transition, with: binding) {
      return true
    }
    return false
  }
  
  /// Check guards for a given binding and a given transition
  private func checkGuards(transition: TransitionType, with binding: [Var: Val]) -> Bool {
    if let conditions = guards[transition] {
      return checkGuards(conditions: conditions, with: binding)
    }
    return true
  }
  
  /// Check guards for a given binding and a given list of conditions
  func checkGuards(conditions: [Guard], with binding: [Var: Val]) -> Bool {
    for condition in conditions {
      if !checkGuard(condition: condition, with: binding) {
        return false
      }
    }
    return true
  }
  
  /// Check a guard for a given binding and a given condition
  func checkGuard(condition: Guard, with binding: [Var: Val]) -> Bool {
    switch (condition.l, condition.r) {
    case (.var(let x), .var(let y)):
      if let xSubs = binding[x], let ySubs = binding[y] {
        return xSubs == ySubs
      }
      return x == y
    case (.val(let x), .val(let y)):
      return x == y
    case (let x, let y):
      if x == y {
        return true
      }
      let newX = bindVariables(expr: x, binding: binding)
      let newY = bindVariables(expr: y, binding: binding)
      return eval(newX) == eval(newY)
    }
  }
  
  /// Substitute variables inside an expression of the inscription language by the corresponding binding.
  /// Care, variables in the string must begin by a $. (e.g.: "$x + 1")
  func bindVariables(
    expr: ILang,
    binding: [Var: Val])
  -> ILang {
    switch expr {
    case .val(_):
      return expr
    case .var(let v):
      if let vSubs = binding[v] {
        return .val(vSubs)
      }
      return expr
    case .exp(let e):
      var res: String = e
      for el in binding.sorted(by: {(b1,b2) in
        return b1.key.count > b2.key.count
      }) {
        switch el.value {
        case .cst(let c):
          res = res.replacingOccurrences(of: "\(el.key)", with: "\(c)")
        default:
          continue
        }
      }
      return .exp(res)
    }
  }

  /// Internal helper to process preconditions and postconditions.
  private static func add(
    arc: ArcDescription,
    to matrix: inout [TransitionType: [PlaceType: ArcLabel]])
  {
    if var column = matrix[arc.transition] {
      precondition(column[arc.place] == nil, "duplicate arc declaration")
      column[arc.place] = arc.labels
      matrix[arc.transition] = column
    } else {
      matrix[arc.transition] = [arc.place: arc.labels]
    }
  }
  
  /// Eval an inscription language expression to a value
  func eval(_ s: ILang) -> Val {
    switch s {
    case .val(let val):
      return val
    case .exp(let e):
      let context = interpreter.saveContext()
      let value = try! "\(interpreter.eval(string: e))"
      interpreter.reloadContext(context: context)
      if value.contains("func") {
        return .cst(value)
      }
      return .cst(value)
    case .var(_):
      fatalError("Try to evaluate a variable which has not been bound.")
    }
  }
  
  /// Does the expression of the inscription language contains a given string ?
  func contains(
    exp: ILang,
    s: String)
  -> Bool {
    switch exp {
    case .var(let v):
      return v.contains(s)
    case .exp(let e):
      return e.contains(s)
    default:
      return false
    }
  }

}

/// A place in a Petri net.
public protocol Place: CaseIterable, Hashable {

  associatedtype Content

}

/// A transition in a Petri net.
public protocol Transition: CaseIterable, Hashable {
}
