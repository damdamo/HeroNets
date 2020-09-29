import Interpreter

/// A Hero net.
///
/// `PetriNet` is a generic type, accepting two types representing the set of places and the set
/// of transitions that structurally compose the model. Both should conform to `CaseIterable`,
/// which guarantees that the set of places (resp. transitions) is bounded, and known statically.
/// The following example illustrates how to declare the places and transition of a simple Petri
/// net representing an on/off switch:
///
///     enum P: Place {
///       typealias Content = Int
///       case on, off
///     }
///
///     enum T: Transition {
///       case switchOn, switchOff
///     }
///
/// Petri net instances are created by providing the list of the preconditions and postconditions
/// that compose them. These should be provided in the form of arc descriptions (i.e. instances of
/// `ArcDescription`) and fed directly to the Petri net's initializer. The following example shows
/// how to create an instance of the on/off switch:
///
///
///     let model = PetriNet<P, T>(
///       .pre(from: .on, to: .switchOff),
///       .post(from: .switchOff, to: .off),
///       .pre(from: .off, to: .switchOn),
///       .post(from: .switchOn, to: .on),
///     )
///
/// Petri net instances only represent the structual part of the corresponding model, meaning that
/// markings should be stored externally. They can however be used to compute the marking resulting
/// from the firing of a particular transition, using the method `fire(transition:from:)`. The
/// following example illustrates this method's usage:
///
///     if let marking = model.fire(.switchOn, from: [.on: 0, .off: 1]) {
///       print(marking)
///     }
///     // Prints "[.on: 1, .off: 0]"
///
public struct HeroNet<PlaceType, TransitionType>
where PlaceType: Place, PlaceType.Content == Multiset<String>, TransitionType: Transition
{

  public typealias ArcLabel = [String]
  
  /// The description of an arc.
  public struct ArcDescription {

    /// The place to which the arc is connected.
    fileprivate let place: PlaceType

    /// The transition to which the arc is connected.
    fileprivate let transition: TransitionType

    /// The arc's label.
    fileprivate let labels: [String]

    /// The arc's direction.
    fileprivate let isPre: Bool

    private init(place: PlaceType, transition: TransitionType, labels: [String], isPre: Bool) {
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
      labeled labels: [String])
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
      labeled labels: [String])
      -> ArcDescription
    {
      return ArcDescription(place: place, transition: transition, labels: labels, isPre: false)
    }

  }

  /// This net's input matrix.
  public let input: [TransitionType: [PlaceType: ArcLabel]]

  /// This net's output matrix.
  public let output: [TransitionType: [PlaceType: ArcLabel]]
  
  /// Interpreter needs to evaluate Hero terms
  public let interpreter: Interpreter


  /// Initializes a Petri net with a sequence describing its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A sequence containing the descriptions of the Petri net's arcs.
  public init<Arcs>(_ arcs: Arcs, interpreter: Interpreter) where Arcs: Sequence, Arcs.Element == ArcDescription {
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
    self.interpreter = interpreter
  }

  /// Initializes a Petri net with descriptions of its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A variadic argument representing the descriptions of the Petri net's arcs.
  public init(_ arcs: ArcDescription..., interpreter: Interpreter) {
    self.init(arcs, interpreter: interpreter)
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
  public func fire(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [String: String])
    -> Marking<PlaceType>? {
    
    var inputMarking: [PlaceType: PlaceType.Content] = [:]
    var outputMarking: [PlaceType: PlaceType.Content] = [:]
    
    // Check Fireability and compute input marking
    if let pre = input[transition] {
      var multiset: Multiset<String> = [:]
      for place in PlaceType.allCases {
        inputMarking[place] = [:]
      }
      for (key,values) in pre {
        for val in values {
          multiset.insert(binding[val]!)
        }
        // Create a multiset for each place of input arcs of the transition
        inputMarking[key] = multiset
        multiset = [:]
      }
      
      // Check is fireable
      if !(marking >= Marking<PlaceType>(inputMarking)), !checkGuards(transition: transition, from: marking, with: binding) {
        return nil
      }
    }
    
    var valOutput = ""
    // Compute result of input arcs
    if let post = output[transition] {
      var multiset: Multiset<String> = [:]
      for place in PlaceType.allCases {
        outputMarking[place] = [:]
      }
      for (key,values) in post {
        for val in values {
          valOutput = "\(try! interpreter.eval(string: bindingSubstitution(str: val, binding: binding)))"
          multiset.insert(valOutput)
        }
        // Create a multiset for each place of output arcs of the transition
        outputMarking[key] = multiset
        multiset = [:]
      }
    }
    
    // Return final result
    return marking - Marking<PlaceType>(inputMarking) + Marking<PlaceType>(outputMarking)
    
  }
  
  public func checkGuards(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [String: String]) -> Bool {
    return false
  }
  
  /// Substitute variables inside a string by corresponding binding
  /// Care, variables in the string must begin by a $. (e.g.: "$x + 1")
  public func bindingSubstitution(str: String, binding: [String: String]) -> String {
    var res: String = str
    for el in binding {
      res = res.replacingOccurrences(of: "$\(el.key)", with: "\(el.value)")
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

}

/// A place in a Petri net.
public protocol Place: CaseIterable, Hashable {

  associatedtype Content

}

/// A transition in a Petri net.
public protocol Transition: CaseIterable, Hashable {}
