import Interpreter

//struct HeroNet {
//
//  typealias Place = String
//  typealias Marking = [Place: [String: Int]]
//
//  let places: Set<Place>
//  let transitions: Set<Transition>
//  let marking: [Place: [String: Int]]
//  let interpreter: Interpreter
//
////  init(places: Set<Place> = [], transitions: Set<Transition>, interpreter: Interpreter) {
////    self.places = places
////    self.transitions = transitions
////    self.interpreter = interpreter
////  }
//
//
//
//  public func computeBindings() {}
//
//}

/// A Petri net.
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
    ///   - label: The arc's label.
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
    ///   - label: The arc's label.
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

  /// Initializes a Petri net with a sequence describing its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A sequence containing the descriptions of the Petri net's arcs.
  public init<Arcs>(_ arcs: Arcs) where Arcs: Sequence, Arcs.Element == ArcDescription {
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
  }

  /// Initializes a Petri net with descriptions of its preconditions and postconditions.
  ///
  /// - Parameters:
  ///   - arcs: A variadic argument representing the descriptions of the Petri net's arcs.
  public init(_ arcs: ArcDescription...) {
    self.init(arcs)
  }

  /// Computes the marking resulting from the firing of the given transition, from the given
  /// marking, assuming the former is fireable.
  ///
  /// - Parameters:
  ///   - transition: The transition to fire.
  ///   - marking: The marking from which the given transition should be fired.
  /// - Returns:
  ///   The marking that results from the firing of the given transition if it is fireable, or
  ///   `nil` otherwise.
  public func fire(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [String: String])
    -> Marking<PlaceType>?
  {
    guard isFireable(transition: transition, from: marking, with: binding) else { return nil }
    
    var newMarking = marking

    let pre = input[transition]
    let post = output[transition]
    
    print(pre)
    print(post)

    for place in PlaceType.allCases {
      print(place)
      if let n = pre?[place] {
        print(n)
//        guard marking[place] >= n
//          else { return nil }
//        newMarking[place] -= n
      }

      if let n = post?[place] {
        //newMarking[place] += n
      }
    }
      return nil
//    return newMarking
  }
  
  // Function to test if a marking is fireable for a specific binding.
  // The goal is to construct a marking corresponding to the sequence to fire.
  // Hence, it compares the both marking and returns true if this marking is included in the current marking
  // Ex. : Result: [p1: {"1","1","2"}, ...] for a transition and a marking (e.g.: [p1: {"1", "2", "1", ...}, ...]) with a binding (e.g.: ["x": "1", "y": "1", "z": "2"])
  // We supposed a transition with an input arc labeled by ["x","y","z"] from p1 to it.
  // Second step, we create
  public func isFireable(transition: TransitionType, from marking: Marking<PlaceType>, with binding: [String: String])
  -> Bool {
    if let pre = input[transition] {
      var multiset: Multiset<String> = [:]
      var mark: [PlaceType: PlaceType.Content] = [:]
      for place in PlaceType.allCases {
        mark[place] = [:]
      }
      for (key,values) in pre {
        for val in values {
          multiset.insert(binding[val]!)
        }
        // Create a multiset for each place of input arcs of the transition
        mark[key] = multiset
        multiset = [:]
      }
      print("-------------")
      print(Marking<PlaceType>(mark))
      print("-------------")
      print(marking)
      return Marking<PlaceType>(mark) <= marking
    } else {
      return true
    }
  }
  
  // public func checkGuards(transition: TransitionType, )

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
