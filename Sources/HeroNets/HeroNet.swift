import Interpreter

/// A Hero net.
///
/// `HeroNet` is a generic type, accepting two types representing the set of places and the set
/// of transitions that structurally compose the model. Both should conform to `CaseIterable`,
/// which guarantees that the set of places (resp. transitions) is bounded, and known statically.
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
///     if let marking = model.fire(transition: .t1, from: marking, with: ["x": "2", "y": "2"]) {
///       print(marking)
///     }
///     // Prints "[.p1: ["1", "3"], .p2: ["4"]]"
///
public struct HeroNet<PlaceType, TransitionType>
where PlaceType: Place, PlaceType.Content == Multiset<String>, TransitionType: Transition
{

  public typealias Label = String
  // The content inside the multiset (e.g.: String)
  public typealias Value = PlaceType.Content.Key
  public typealias ArcLabel = [Label]
  
  /// The description of an arc.
  public struct ArcDescription {

    /// The place to which the arc is connected.
    fileprivate let place: PlaceType

    /// The transition to which the arc is connected.
    fileprivate let transition: TransitionType

    /// The arc's label.
    fileprivate let labels: [Label]

    /// The arc's direction.
    fileprivate let isPre: Bool

    private init(place: PlaceType, transition: TransitionType, labels: [Label], isPre: Bool) {
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
      labeled labels: [Label])
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
      labeled labels: [Label])
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
  public let guards: TotalMap<TransitionType, [Pair<Value, Value>]?>
  
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
  public init<Arcs>(_ arcs: Arcs, guards: [TransitionType: [Pair<Value, Value>]?], interpreter: Interpreter) where Arcs: Sequence, Arcs.Element == ArcDescription {
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
    
    // A trick is needed with the Alpine interpreter, cause the first time a module is called it loads built-in operations. Thus, we want to keep them for the rest of operations.
    // Otherwise, built-in operations are created the first time the interpreter is called for an operation. It works the first time, however, each time we call the interpreter, we save and reload the context
    // So, the interpreter is reset at a time where it does not know built-it operations. Moreover, it does not reload built-in operations. It leads to an error in specific cases where the user does not create its own module.
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
  public init(_ arcs: ArcDescription..., guards: [TransitionType: [Pair<Value, Value>]?], interpreter: Interpreter) {
    self.init(arcs, guards: guards, interpreter: interpreter)
  }
    
  /// Initializes a Petri net with all components.
  init(
    input: [TransitionType: [PlaceType: ArcLabel]],
    output: [TransitionType: [PlaceType: ArcLabel]],
    guards: TotalMap<TransitionType, [Pair<Value, Value>]?>,
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
  ///   - marking: The marking from which the given transition should be fired.
  ///   - binding: Bind values on the arcs
  /// - Returns:
  ///   The marking that results from the firing of the given transition if it is fireable and guards check, or
  ///   `nil` otherwise.
  public func fire(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [Label: Value])
    -> Marking<PlaceType>? {
    
    guard isFireable(transition: transition, from: marking, with: binding) else {
      return nil
    }
    
    var inputMarking: [PlaceType: PlaceType.Content] = [:]
    var outputMarking: [PlaceType: PlaceType.Content] = [:]
    
    // Compute input marking
    if let pre = input[transition] {
      var multiset: Multiset<String> = [:]
      for place in PlaceType.allCases {
        inputMarking[place] = [:]
      }
      // In the case of pre, expressions is just a list of labels
      for (place, expressions) in pre {
        for expr in expressions {
          if expr.contains("$") {
            multiset.insert(binding[expr]!)
          } else {
            multiset.insert(expr)
          }
        }
        // Create a multiset for each place of input arcs of the transition
        inputMarking[place] = multiset
        multiset = [:]
      }
    }
    
    // Interpreter evaluate terms which are expressed by String
    var valOutput: String = ""
    var exprSubs: String = ""
    // Compute result of input arcs
    if let post = output[transition] {
      var multiset: Multiset<String> = [:]
      for place in PlaceType.allCases {
        outputMarking[place] = [:]
      }
      // In the case of post, expressions is a list of strings containing labels
      for (place, expressions) in post {
        for expr in expressions {
          exprSubs = bindingSubstitution(expr: expr, binding: binding)
          valOutput = eval(exprSubs)
          // In the case or we get the signature of a function, we just return the function name
          if valOutput.contains("function") {
            multiset.insert(exprSubs)
          } else {
            multiset.insert(valOutput)
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
  
  // Check the fireability of a transition
  public func isFireable(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [Label: String]) -> Bool {
    var multiset: Multiset<String>
    if let pre = input[transition] {
      for (place,variables) in pre {
        multiset = [:]
        for var_ in variables {
          if let varSubs = binding[var_] {
            multiset.insert(varSubs)
          } else {
            return false
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
  
  // Check guards of a transition
  private func checkGuards(transition: TransitionType, with binding: [Label: Value]) -> Bool {
    if let conditions = guards[transition] {
      return checkGuards(conditions: conditions, with: binding)
    }
    return true
  }
  
  // Check guards for a list of conditions
  func checkGuards(conditions: [Pair<Value, Value>], with binding: [Label: Value]) -> Bool {
    for condition in conditions {
      if !checkGuard(condition: condition, with: binding) {
        return false
      }
    }
    return true
  }
  
  // Check a guard
  func checkGuard(condition: Pair<Value, Value>, with binding: [Label: Value]) -> Bool {
    let lhs = bindingSubstitution(expr: condition.l, binding: binding)
    let rhs = bindingSubstitution(expr: condition.r, binding: binding)
    // Check if both term are equals, thanks to the syntactic equivalence !
    // Moreover, allows to compare functions in a syntactic way
    if lhs != rhs {
      let v1 = eval(lhs)
      let v2 = eval(rhs)
      // If values are different and not are signature functions
      if "\(v1)" != "\(v2)" || "\(v1)".contains("function") {
        return false
      }
    }
    return true
  }
  
  /// Substitute variables inside a string by corresponding binding
  /// Care, variables in the string must begin by a $. (e.g.: "$x + 1")
  func bindingSubstitution(expr: Value, binding: [Label: Value]) -> String {
    var res: String = "\(expr)"
    // The sorting is needed to avoid conflict where a variable is shorter than another and could take its place
    // E.g.: $x = 2, $x_1 = 42, if the expression is $x_1 and the binding $x is read before, $x_1 -> 1_1
    for el in binding.sorted(by: {(b1,b2) in
      return b1.key.count > b2.key.count
    }) {
      res = res.replacingOccurrences(of: "\(el.key)", with: "\(el.value)")
    }
    return res
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
  
  func eval(_ s: Value) -> Value {
    let context = interpreter.saveContext()
    let value = try! "\(interpreter.eval(string: s))"
    interpreter.reloadContext(context: context)
    if value.contains("func") {
      return s
    }
    return value
  }

}

/// A place in a Petri net.
public protocol Place: CaseIterable, Hashable {

  associatedtype Content

}

/// A transition in a Petri net.
public protocol Transition: CaseIterable, Hashable {
}
