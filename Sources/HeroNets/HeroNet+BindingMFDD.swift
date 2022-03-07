//import DDKit
//import Interpreter
//import Foundation
//
//extension HeroNet where PlaceType.Content == Multiset<Val>, PlaceType: Comparable {
//  
////  public typealias MarkingMFDD = MFDD<PlaceType,PlaceType.Content>
////  public typealias MarkingMFDDFactory = MFDDFactory<KeyMarking, ValueMarking>
////  var morphisms: MFDDMorphismFactory<KeyMarking, ValueMarking> { markingMFDDFactory.morphisms }
//  public typealias MarkingMorphismFactory = MFDDMorphismFactory<KeyMarking, ValueMarking>
//
//  
//  /// - Parameters:
//  ///   - for transition: The transition to compute bindings
//  ///   - with marking: The marking to use
//  ///   - factory: The factory needed to work on MFDD
//  /// - Returns:
//  ///   Returns all enabled bindings for a specific transition and a specific marking
//  public func fireableBindings(
//    for transition: TransitionType,
//    with marking: MarkingMFDD,
//    bindingFactory: BindingMFDDFactory,
//    markingMorphismFactory: MarkingMorphismFactory,
//    isStateSpaceComputation: Bool = false)
//  -> BindingMFDD {
//    var net: HeroNet = self
//    // Static optimization, only depends on the structure of the net
//    if !isStateSpaceComputation {
//      net = computeStaticOptimizedNet()
//    }
//    // Dynamic optimization, depends on the structure of the net and the marking
//    let tupleDynamicOptimizedNetAndnewMarking = net.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
//    if let (dynamicOptimizedNet, newMarking) = tupleDynamicOptimizedNetAndnewMarking {
//      return dynamicOptimizedNet.computeEnabledBindings(for: transition, marking: newMarking, factory: factory)
//    }
//    return factory.zero
//  }
//  
//  
//  
//  /// Computes dynamic optimizations on the net and constructs dictionnary that binds place to their labels and their corresponding values
//  /// There is one optimization:
//  /// - Remove constant on arcs: Remove the constant on the arc and remove it into the marking
//  /// - Parameters:
//  ///   - transition: The current transition
//  ///   - marking: The current marking
//  /// - Returns:
//  ///   Returns a new net modify with the optimizations and a dictionnary that contains for each place, possible values for labels
//  public func computeDynamicOptimizedNet(
//    transition: TransitionType,
//    marking: MarkingMFDD,
//    markingMorphismFactory: MarkingMorphismFactory)
//  -> (HeroNet, MarkingMFDD)? {
//    
//    // Optimizations on constant on arcs, removing it from the net and from the marking in  the place
//    if let (netWithoutConstant, markingWithoutConstant) = consumeConstantOnArcs(transition: transition, marking: marking, markingMorphismFactory: markingMorphismFactory) {
//      return (netWithoutConstant, markingWithoutConstant)
//    }
//    return nil
//  }
//  
//  /// During the firing, consume directly the arc constants from the marking before starting the computation
////  func consumeConstantOnArcs(
////    transition: TransitionType,
////    marking: MarkingMFDD,
////    markingMorphismFactory: MarkingMorphismFactory)
////  -> (HeroNet, MarkingMFDD)? {
////    var newMarking = marking
////    var newInput = input
////    
//////    var ms: Multiset<Val> = ["1"]
//////    var removeValue = markingMorphismFactory.removeValueInMarking(excluding: [(key: .p1, value: ms)])
////    
////    if let pre = input[transition] {
////      for (place, labels) in pre {
////        for label in labels {
////          switch label {
////          case .val(let val):
////            if newMarking[place].occurences(of: val) > 0 {
////              newMarking[place].remove(val)
////            } else {
////              return nil
////            }
////            // It removes the constant once time
////            newInput[transition]![place]!.remove(.val(val))
////          default:
////            continue
////          }
////        }
////      }
////    }
////    
////    return (
////      HeroNet(input: newInput, output: output, guards: guards, interpreter: interpreter),
////      newMarking
////    )
////    
////  }
//  
//  
//}
