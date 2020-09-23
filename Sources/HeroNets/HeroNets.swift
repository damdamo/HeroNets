import Interpreter

struct HeroNet {
  
  typealias Place = String
  typealias Marking = [Place: [String: Int]]
  
  let places: Set<Place>
  let transitions: Set<Transition>
  let marking: [Place: [String: Int]]
  let interpreter: Interpreter
  
//  init(places: Set<Place> = [], transitions: Set<Transition>, interpreter: Interpreter) {
//    self.places = places
//    self.transitions = transitions
//    self.interpreter = interpreter
//  }
  

  
  public func computeBindings() {}
  
}
