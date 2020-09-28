/// A marking of a Petri net.
///
/// A marking is a mapping that associates the places of a Petri net to the tokens they contain.
///
/// An algebra is defined over markings if the type used to represent the tokens associated with
/// each place (i.e. `PlaceType`) allows it. More specifically, markings are comparable if tokens
/// are too, and even conform to `AdditiveArithmetic` if tokens do to.
///
/// The following example illustrates how to perform arithmetic operations of markings:
///
///     let m0: Marking<P> = [.p0: 1, .p1: 2]
///     let m1: Marking<P> = [.p0: 0, .p1: 1]
///     print(m0 + m1)
///     // Prints "[.p0: 1, .p1: 3]"
///
public struct Marking<PlaceType> where PlaceType: Place {

  /// The total map that backs this marking.
  fileprivate var storage: TotalMap<PlaceType, PlaceType.Content>

  /// Initializes a marking with a total map.
  ///
  /// - Parameters:
  ///   - mapping: A total map representing this marking.
  public init(_ mapping: TotalMap<PlaceType, PlaceType.Content>) {
    self.storage = mapping
  }

  /// Initializes a marking with a dictionary.
  ///
  /// - Parameters:
  ///   - mapping: A dictionary representing this marking.
  ///
  /// The following example illustrates the use of this initializer:
  ///
  ///     let marking = Marking([.p0: 42, .p1: 1337])
  ///
  /// - Warning:
  ///   The given dictionary must be defined for all places, otherwise an error will be triggered
  ///   at runtime.
  public init(_ mapping: [PlaceType: PlaceType.Content]) {
    self.storage = TotalMap(mapping)
  }

  /// Initializes a marking with a function.
  ///
  /// - Parameters:
  ///   - mapping: A function mapping places to the tokens they contain.
  ///
  /// The following example illustrates the use of this initializer:
  ///
  ///     let marking = Marking { place in
  ///       switch place {
  ///       case .p0: return 42
  ///       case .p1: return 1337
  ///       }
  ///     }
  ///
  public init(_ mapping: (PlaceType) throws -> PlaceType.Content) rethrows {
    self.storage = try TotalMap(mapping)
  }

  /// Accesses the tokens associated with the given place for reading and writing.
  public subscript(place: PlaceType) -> PlaceType.Content {
    get { return storage[place] }
    set { storage[place] = newValue }
  }

  /// A collection containing just the places of the marking.
  public var places: PlaceType.AllCases {
    return PlaceType.allCases
  }

}

extension Marking: ExpressibleByDictionaryLiteral {

  public init(dictionaryLiteral elements: (PlaceType, PlaceType.Content)...) {
    let mapping = Dictionary(uniqueKeysWithValues: elements)
    self.storage = TotalMap(mapping)
  }

}

extension Marking: Equatable where PlaceType.Content: Equatable {}

extension Marking: Hashable where PlaceType.Content: Hashable {}

extension Marking: Comparable where PlaceType.Content: Comparable & Sequence {

  public static func < (lhs: Marking, rhs: Marking) -> Bool {
    for place in PlaceType.allCases {
      if lhs[place] >= rhs[place] {
        return false
      }
    }
    return true
  }
  
  public static func > (lhs: Marking, rhs: Marking) -> Bool {
    for place in PlaceType.allCases {
      if lhs[place] <= rhs[place] {
        return false
      }
    }
    return true
  }
  
  public static func <= (lhs: Marking, rhs: Marking) -> Bool {
    for place in PlaceType.allCases {
      if lhs[place] > rhs[place] {
        print(lhs[place] > rhs[place])
        print(lhs[place])
        print(rhs[place])
        return false
      }
    }
    return true
  }
  
  public static func >= (lhs: Marking, rhs: Marking) -> Bool {
    for place in PlaceType.allCases {
      if lhs[place] < rhs[place] {
        return false
      }
    }
    return true
  }
  
}

extension Marking: AdditiveArithmetic where PlaceType.Content: AdditiveArithmetic {

  /// Initializes a marking with a dictionary, associating `PlaceType.Content.zero` for unassigned
  /// places.
  ///
  /// - Parameters:
  ///   - mapping: A dictionary representing this marking.
  ///
  /// The following example illustrates the use of this initializer:
  ///
  ///     let marking = Marking([.p0: 42])
  ///     print(marking)
  ///     // Prints "[.p0: 42, .p1: 0]"
  ///
  public init(partial mapping: [PlaceType: PlaceType.Content]) {
    self.storage = TotalMap(partial: mapping, defaultValue: .zero)
  }

  /// A marking in which all places are associated with `PlaceType.Content.zero`.
  public static var zero: Marking {
    return Marking { _ in PlaceType.Content.zero }
  }

  public static func + (lhs: Marking, rhs: Marking) -> Marking {
    return Marking { key in lhs[key] + rhs[key] }
  }

  public static func += (lhs: inout Marking, rhs: Marking) {
    for place in PlaceType.allCases {
      lhs[place] += rhs[place]
    }
  }

  public static func - (lhs: Marking, rhs: Marking) -> Marking {
    return Marking { place in lhs[place] - rhs[place] }
  }

  public static func -= (lhs: inout Marking, rhs: Marking) {
    for place in PlaceType.allCases {
      lhs[place] -= rhs[place]
    }
  }

}

extension Marking: CustomStringConvertible {

  public var description: String {
    return String(describing: storage)
  }

}
