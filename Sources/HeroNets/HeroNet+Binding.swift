import DDKit
import Interpreter
import Foundation

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
  
  public typealias KeyMFDDVar = KeyMFDD<Var>
  public typealias BindingMFDD = MFDD<KeyMFDDVar, Val>
  public typealias BindingMFDDFactory = MFDDFactory<KeyMFDDVar, Val>
    
  /// Compute the enabled bindings for a transition and a marking. The enable bindings represent all possible maping for each variable of a transition, which are fireable. Instead oof keeping the enabled transitions as a set, we use a MFDD structure (Map family decision diagram) which is an implicit and compact representation based on the theory on DD (Decision diagrams).
  /// A factory has to be created outside the scope that allows to manage the DD efficiently. (e.g.: `let factory = MFDDFactory<KeyMFDDVar,ValueMFDD>()`
  /// The factory manages references and ensures the unicity of each value inside a MFDD. It keeps in memory previous operations to avoid to recompute the same operation many times. The factory can be passed between different computations that manipulate the same transitions or marking.
  /// In an effort to enhance the computation, two optimizations have been created:
  /// - Static optimization: Based on the structure of the net, it does not depend on the marking. It will compute a new net based on it. (e.g.: Constant propagation)
  /// - Dynamic optimization: Based on structure and/or the marking, it modifies the structure and the current marking. (e.g.: Reduce constant on arcs)
  /// When optimizations are applied, the computation of the MFDD can start. MFDD takes advantage of homorphisms to apply operations directly on the compact representation, instead of working on a naive representation with sets.
  /// - Parameters:
  ///   - for transition: The transition to compute bindings
  ///   - with marking: The marking to use
  ///   - factory: The factory needed to work on MFDD
  /// - Returns:
  ///   Returns all enabled bindings for a specific transition and a specific marking
  public func fireableBindings(
    for transition: TransitionType,
    with marking: Marking<PlaceType>,
    factory: BindingMFDDFactory,
    isStateSpaceComputation: Bool = false)
  -> BindingMFDD {
    var net: HeroNet = self
    // Static optimization, only depends on the structure of the net
    if !isStateSpaceComputation {
      net = computeStaticOptimizedNet()
    }
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = net.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    if let (dynamicOptimizedNet, newMarking) = tupleDynamicOptimizedNetAndnewMarking {
      return dynamicOptimizedNet.computeEnabledBindings(for: transition, marking: newMarking, factory: factory)
    }
    return factory.zero
  }


  // --------------------------------------------------------------------------------- //
  // ----------------------- Functions for static optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
  /// Takes the input net and optimizes. Current static optimizations are based on constant and variable propagation.
  /// In other words, if a guard checks that a variable is equal to another variable, or a variable is equal to a constant, the guard is removed and all variables are substituted by the corresponding new variable or value.
  /// This optimization is purely static and is only based on the structure of the net. The marking is not taken into account.
  /// - Returns:
  ///   Returns a static optimized net
  public func computeStaticOptimizedNet() -> HeroNet {
    
    var netOptimized = self
    for transition in TransitionType.allCases {
      netOptimized = netOptimized.constantPropagationVariable(transition: transition)
      netOptimized = netOptimized.constantPropagationValue(transition: transition)
    }
    return netOptimized
  }
  
  /// The constant propagation optimization uses guard of the form "x = constant expression" to replace all occurences of x by the constant expression in every possible expressions (e.g.: arcs, guards). It returns a net where all occurences of a variable is substituted by the value.
  private func constantPropagationValue(
    transition: TransitionType)
  -> HeroNet {
    if let conditions = guards[transition] {
      // Isolate condition with a unique variable
      let (constantLabels, condRest) = getConstantLabels(conditions: conditions)
      // We do not keep condition with a unique label in the future net !
      var guardsTemp = guards
      guardsTemp[transition] = condRest
      let netTemp = HeroNet(input: input, output: output, guards: guardsTemp, interpreter: interpreter)
      return replaceVarsForATransition(varToValue: constantLabels, transition: transition, net: netTemp)
    }
    return self
  }
  
  /// Replace all occurence of a list of variables by their corresponding value, for a specific transition.
  func replaceVarsForATransition(
    varToValue: [Var: Val],
    transition: TransitionType,
    net: HeroNet)
  -> HeroNet {
    var newInput = net.input
    var newOutput = net.output
    var newGuards = net.guards
    
    // TODO: Insert and remove all in one using something like distinctMember
    if let pre = newInput[transition] {
      for (place, labels) in pre {
        for label in labels {
          switch label {
          case .var(let v):
            if let newV = varToValue[v] {
              newInput[transition]![place]!
                .insert(.val(newV))
              newInput[transition]![place]!
                .remove(label)
            }
          default:
            continue
          }
        }
      }
    }
    
    if let post = newOutput[transition] {
      for (place, labels) in post {
        for label in labels {
          switch label {
          case .var(let v):
            if let newV = varToValue[v] {
              newOutput[transition]![place]!
                .insert(.val(newV))
              newOutput[transition]![place]!
                .remove(label)
            }
          default:
            continue
          }
        }
      }
    }
    
    if let _ = guards[transition] {
      newGuards[transition] = newGuards[transition]!.compactMap({(cond) in
        var l = cond.l
        var r = cond.r
        
        switch l {
        case .var(let v):
          if let res = varToValue[v] {
            l = .val(res)
          }
        case .exp(let e):
          for (var_, val) in varToValue {
            switch val {
            case .cst(let c):
              l = .exp(e.replacingOccurrences(of: var_, with: c))
            case .btk:
              fatalError("You try to substitue a variable by a token inside an expression")
            }
          }
        case .val(_):
          break
        }
        
        switch r {
        case .var(let v):
          if let res = varToValue[v] {
            r = .val(res)
          }
        case .exp(let e):
          for (var_, val) in varToValue {
            switch val {
            case .cst(let c):
              r = .exp(e.replacingOccurrences(of: var_, with: c))
            case .btk:
              fatalError("You try to substitue a variable by a token inside an expression")
            }
          }
        case .val(_):
          break
        }
        
        if l == r {
          return nil
        }
        return Pair(l,r)
      })
    }
        
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: interpreter)
  }
  
  /// Replace all occurence of a list of variables by their new corresponding variable name, for a specific transition.
  func replaceVarsForATransition(
    varToVar: [Var: Var],
    transition: TransitionType,
    net: HeroNet)
  -> HeroNet {
    var newInput = net.input
    var newOutput = net.output
    var newGuards = net.guards
    
    // TODO: Insert and remove all in one using something like distinctMember
    if let pre = newInput[transition] {
      for (place, labels) in pre {
        for label in labels {
          switch label {
          case .var(let v):
            if let newV = varToVar[v] {
              newInput[transition]![place]!
                .insert(.var(newV))
              newInput[transition]![place]!
                .remove(label)
            }
          default:
            continue
          }
        }
      }
    }
    
    if let post = newOutput[transition] {
      for (place, labels) in post {
        for label in labels {
          switch label {
          case .var(let v):
            if let newV = varToVar[v] {
              newOutput[transition]![place]!
                .insert(.var(newV))
              newOutput[transition]![place]!
                .remove(label)
            }
          case .exp(let e):
            for (varSource, varTarget) in varToVar {
              newOutput[transition]![place]!
                .insert(.exp(e.replacingOccurrences(of: varSource, with: varTarget)))
            }
          default:
            continue
          }
        }
      }
    }
    
    if let _ = guards[transition] {
      newGuards[transition] = newGuards[transition]!.compactMap({(cond) in
        var l = cond.l
        var r = cond.r
        
        switch l {
        case .var(let v):
          if let res = varToVar[v] {
            l = .var(res)
          }
        case .exp(let e):
          for (varSource, varTarget) in varToVar {
            l = .exp(e.replacingOccurrences(of: varSource, with: varTarget))
          }
        case .val(_):
          break
        }
        
        switch r {
        case .var(let v):
          if let res = varToVar[v] {
            r = .var(res)
          }
        case .exp(let e):
          for (varSource, varTarget) in varToVar {
            r = .exp(e.replacingOccurrences(of: varSource, with: varTarget))
          }
        case .val(_):
          break
        }
        
        if l == r {
          return nil
        }
        return Pair(l,r)
      })
    }
        
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: interpreter)
  }
  
  
  /// Optimization function that takes conditions of the form "x = y" and replaces each occurence of x by y in the net. Then, it removes the condition.
  private func constantPropagationVariable(
    transition: TransitionType)
  -> HeroNet {
    // Equality guards
    let equivalentVariables = createDicOfEquivalentLabel(transition: transition)
    return replaceVarsForATransition(varToVar: equivalentVariables, transition: transition, net: self)
  }
  
  /// Creates a dictionnary from the equivalent label that binds a label to its new name. It means that if we have a condition of the form " x = y", a new entry will be added in the dictionnary (e.g.: [x:y]). At the end this dictionnary will  be used to know which labels has to be replaced.
  private func createDicOfEquivalentLabel(
    transition: TransitionType)
  -> [Var: Var] {
    
    guard let _ = guards[transition] else { return [:] }
    
    var res: [Var: Var] = [:]
    if let conditions = guards[transition] {
      for condition in conditions {
        switch (condition.l, condition.r) {
        case (.var(let v1), .var(let v2)):
          res[v1] = v2
        default:
          continue
        }
      }
    }
    return res
  }
  
  /// Isolate conditions of the form: someVar = someVal.
  private func getConstantLabels(
    conditions: [Guard]?)
  -> (constantLabels: [Var: Val], restGuards: [Guard]) {

    var constantLabels: [Var: Val] = [:]
    var restGuards: [Guard] = []
    
    if let conds = conditions {
      for cond in conds {
        switch (cond.l, cond.r) {
        case (.var(let v), .val(let val)):
          if let _ = constantLabels[v] {
            fatalError("A constant is assigned more than two times to the same variable")
          }
          constantLabels[v] = val
        case (.val(let val), .var(let v)):
          if let _ = constantLabels[v] {
            fatalError("A constant is assigned more than two times to the same variable")
          }
          constantLabels[v] = val
        default:
          restGuards.append(cond)
        }
      }
    }
    return (constantLabels: constantLabels, restGuards: restGuards)
  }
  
  // --------------------------------------------------------------------------------- //
  // -------------------- End of functions for static optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ---------------------- Functions for dynamic optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
  /// Computes dynamic optimizations on the net and constructs dictionnary that binds place to their labels and their corresponding values
  /// There is one optimization:
  /// - Remove constant on arcs: Remove the constant on the arc and remove it into the marking
  /// - Parameters:
  ///   - transition: The current transition
  ///   - marking: The current marking
  /// - Returns:
  ///   Returns a new net modify with the optimizations and a dictionnary that contains for each place, possible values for labels
  public func computeDynamicOptimizedNet(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> (HeroNet, Marking<PlaceType>)? {
    // Optimizations on constant on arcs, removing it from the net and from the marking in  the place
    if let (netWithoutConstant, markingWithoutConstant) = consumeConstantOnArcs(transition: transition, marking: marking) {
      return (netWithoutConstant, markingWithoutConstant)
    }
    return nil
  }
  
  /// During the firing, consume directly the arc constants from the marking before starting the computation
  func consumeConstantOnArcs(
    transition: TransitionType,
    marking: Marking<PlaceType>)
  -> (HeroNet, Marking<PlaceType>)? {
    var newMarking = marking
    var newInput = input
    
    if let pre = input[transition] {
      for (place, labels) in pre {
        for label in labels {
          switch label {
          case .val(let val):
            if newMarking[place].occurences(of: val) > 0 {
              newMarking[place].remove(val)
            } else {
              return nil
            }
            // It removes the constant once time
            newInput[transition]![place]!.remove(.val(val))
          default:
            continue
          }
        }
      }
    }
    
    return (
      HeroNet(input: newInput, output: output, guards: guards, interpreter: interpreter),
      newMarking
    )
    
  }
  
  // --------------------------------------------------------------------------------- //
  // ------------------- End of functions for dynamic optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ----------------------------- Functions for MFDD -------------------------------- //
  // --------------------------------------------------------------------------------- //
  
  /// Compute enabled bindings for a transition and a marking. Use a MFDD to do the computation.
  private func computeEnabledBindings(
    for transition: TransitionType,
    marking: Marking<PlaceType>,
    factory: BindingMFDDFactory)
  -> BindingMFDD {
    
    let keySet = createKeys(transition: transition)
    let dependentKeys = computeDependentKeys(transition: transition, keySet: keySet)

    let (dependentPlaceToKeyToValues, independentKeyToValues) = computeDependentAndIndependentKeyValues(keySet: keySet, dependentKeys: dependentKeys, marking: marking, transition: transition)

    var mfddPointer = constructMFDD(placeToKeyToValues: dependentPlaceToKeyToValues, transition:transition, factory: factory)

    // If there are conditions, we have to apply them on the MFDD
    if let conditions = guards[transition] {
      let keysToGuards = createKeysToGuards(transition: transition, keySet: keySet)
      // Apply guards
      mfddPointer = applyCondition(
        mfddPointer: mfddPointer,
        guards: conditions,
        keysToGuards: keysToGuards,
        dependentKeys: dependentKeys,
        factory: factory
      )
    }

    // Add independent labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
    mfddPointer = addIndependentLabel(mfddPointer: mfddPointer, independentKeyToValues: independentKeyToValues, factory: factory)
    return MFDD(pointer: mfddPointer, factory: factory)
  }
  
  /// Compute enabled bindings for a transition and a marking. This version is used for state space computation. It computes some information statically to avoid to recompute it each time.
  private func computeEnabledBindings(
    for transition: TransitionType,
    marking: Marking<PlaceType>,
    keySet: Set<KeyMFDDVar>,
    dependentKeys: Set<KeyMFDDVar>,
    keysToGuards: [Set<KeyMFDDVar>: Set<Guard>],
    factory: BindingMFDDFactory)
  -> BindingMFDD {

    let (dependentPlaceToKeyToValues, independentKeyToValues) = computeDependentAndIndependentKeyValues(keySet: keySet, dependentKeys: dependentKeys, marking: marking, transition: transition)
    
    var mfddPointer = constructMFDD(placeToKeyToValues: dependentPlaceToKeyToValues, transition:transition, factory: factory)
        
    // If there are conditions, we have to apply them on the MFDD
    if let conditions = guards[transition] {
      // Apply guards
      mfddPointer = applyCondition(
        mfddPointer: mfddPointer,
        guards: conditions,
        keysToGuards: keysToGuards,
        dependentKeys: dependentKeys,
        factory: factory
      )
    }
    // Add independent labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
    mfddPointer = addIndependentLabel(mfddPointer: mfddPointer, independentKeyToValues: independentKeyToValues, factory: factory)
    return MFDD(pointer: mfddPointer, factory: factory)
  }
  
  func createKeysToGuards(transition: TransitionType, keySet: Set<KeyMFDDVar>) -> [Set<KeyMFDDVar>: Set<Guard>] {
    
    var keysToGuards: [Set<KeyMFDDVar>: Set<Guard>] = [:]
    var keys: Set<KeyMFDDVar>
    
    if let conditions = guards[transition] {
      for cond in conditions {
        keys = []
        for key in keySet {
          if contains(exp: cond.l, s: key.label) || contains(exp: cond.r, s: key.label) {
              keys.insert(key)
          }
        }
        if !keys.isEmpty {
          if let _ = keysToGuards[keys] {
            keysToGuards[keys]!.insert(cond)
          } else {
            keysToGuards[keys] = [cond]
          }
        }
      }
    }
    
    return keysToGuards
  }
  
  func createKeys(transition: TransitionType) -> Set<KeyMFDDVar> {
    
    var totalOrder: [Pair<Var, Var>] = []
    var keySet: Set<KeyMFDDVar> = []
    
    let variableSet = createSetOfVariableLabel(transition: transition)
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let varWeights = computeWeightScores(
      variableSet: variableSet,
      conditions: guards[transition]
    )
          
    // Compute a total order for the labels of a transition
    if let lw = varWeights {
      totalOrder = createTotalOrder(variables: variableSet.sorted(by: {(label1, label2) -> Bool in
        lw[label1]! < lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(variables: Array(variableSet))
    }
    
    // Prepare set of keys for the transition
    for v in variableSet {
      keySet.insert(KeyMFDDVar(label: v, couple: totalOrder))
    }
    
    return keySet
  }
  
  
  
  // Compute dependent and independent keys of a transition
  // Suppose that the net has been already optimized
  func computeDependentKeys(
    transition: TransitionType,
    keySet: Set<KeyMFDDVar>
  ) -> Set<KeyMFDDVar> {

    var dependentKeys: Set<KeyMFDDVar> = []
    
    // Variable in guards are dependent
    if let conditions = guards[transition] {
      for condition in conditions {
        for key in keySet {
          if contains(exp: condition.l, s: key.label) || contains(exp: condition.r, s: key.label) {
            dependentKeys.insert(key)
          }
        }
      }
    }
    
    // If there are multiple variable on the same arc, keys are dependent
    var occurenceOfVar: [Var: Int] = [:]
    if let placeToLabels = input[transition] {
      for (_, labels) in placeToLabels {
        if labels.count > 1 {
          for label in labels {
            switch label {
            case .var(let v):
              dependentKeys.insert(keySet.first(where: {$0.label == v})!)
            default:
              continue
            }
          }
        } else {
          if let label = labels.first {
            switch label {
            case .var(let v):
              if let _ = occurenceOfVar[v] {
                occurenceOfVar[v]! += 1
              } else {
                occurenceOfVar[v] = 1
              }
            default:
              continue
            }
          }
        }
      }
    }
    
    // If a same variable appears on different arcs
    for (v, occ) in occurenceOfVar {
      if occ > 1 {
        dependentKeys.insert(keySet.first(where: {$0.label == v})!)
      }
    }
    
    return dependentKeys
  }
  
  func computeDependentAndIndependentKeyValues(
    keySet: Set<KeyMFDDVar>,
    dependentKeys: Set<KeyMFDDVar>,
    marking: Marking<PlaceType>,
    transition: TransitionType)
  -> ([PlaceType: [KeyMFDDVar: MultisetVal]], [KeyMFDDVar: MultisetVal]) {

    var independentKeysToValues: [KeyMFDDVar: MultisetVal] = [:]
    var placeToDependentKeysToValues: [PlaceType: [KeyMFDDVar: MultisetVal]] = [:]
    var varToKey: [Var: KeyMFDDVar] = [:]
    
    for key in keySet {
      varToKey[key.label] = key
    }
    
    if let placeToLabels = input[transition] {
      for (place, labels) in placeToLabels {
        placeToDependentKeysToValues[place] = [:]
        for label in labels.distinctMembers {
          switch label {
          case .var(let v):
            if dependentKeys.contains(varToKey[v]!) {
              placeToDependentKeysToValues[place]![varToKey[v]!] = marking[place]
            } else {
              independentKeysToValues[varToKey[v]!] = marking[place]
            }
          default:
            continue
          }
        }
      }
    }
    
    return (placeToDependentKeysToValues, independentKeysToValues)
  }
  
  /// Takes each independent keys and construct their own MFDD. Each MFDD can be simply added in the current MFDD.
  /// - Parameters:
  ///   - mfddPointer:Current mfdd pointer
  ///   - independentKeyToValues: List of keys with their expressions with no influenced between keys in the net.
  ///   - factory: Current factory
  /// - Returns:
  ///   Returns a new mfdd pointer where values of the independent keys have been added.
  private func addIndependentLabel(mfddPointer: BindingMFDD.Pointer, independentKeyToValues: [KeyMFDDVar: MultisetVal], factory: BindingMFDDFactory) -> BindingMFDD.Pointer {
    if independentKeyToValues.count > 0 {
      let mfddPointerForIndependentKeys = constructMFDDIndependentKeys(keyToExprs: independentKeyToValues, factory: factory)
      return factory.concatAndFilterInclude(mfddPointer, mfddPointerForIndependentKeys)
    }
    return mfddPointer
  }
  
  /// Construct the MFDD for independent keys, without the need to filter.
  /// - Parameters:
  ///   - keyToExprs: Each key is bound to a multiset of expressions
  ///   - factory: Current factory
  /// - Returns:
  ///   Returns the MFDD that represents all independent keys with their corresponding values
  private func constructMFDDIndependentKeys(
    keyToExprs: [KeyMFDDVar: MultisetVal],
    factory: BindingMFDDFactory
  ) -> BindingMFDD.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, values) = keyToExprs.sorted(by: {$0.key < $1.key}).first {
      var take: [Val: BindingMFDD.Pointer] = [:]
      var keyToExprsFirstDrop = keyToExprs
      keyToExprsFirstDrop.removeValue(forKey: key)
      
      for el in values {
        // Check we have enough element in values
        take[el] = constructMFDDIndependentKeys(
          keyToExprs: keyToExprsFirstDrop,
          factory: factory
        )
      }
      return factory.node(key: key, take: take, skip: factory.zero.pointer)
    }
    return factory.zero.pointer
  }
  
  
  /// Create a new mfdd pointer from the current mfdd where we filter values which does not satisfy the condition
  /// - Parameters:
  ///   - mfddPointer: The complete mfdd pointer without any guards.
  ///   - condition: The condition the mfdd has to satisfy
  ///   - keySet: The list of all keys imply in the transition
  ///   - factory: The mfdd factory
  /// - Returns:
  ///   Returns the new mfdd that have applied the condition.
  private func applyCondition(
    mfddPointer: BindingMFDD.Pointer,
    guards: [Guard],
    keysToGuards: [Set<KeyMFDDVar>: Set<Guard>],
    dependentKeys: Set<KeyMFDDVar>,
    factory: BindingMFDDFactory
  ) -> BindingMFDD.Pointer {
    var morphisms: MFDDMorphismFactory<KeyMFDDVar, Val> { factory.morphisms }
    let morphism = guardFilter(
      keys: dependentKeys,
      guards: guards,
      keysToGuards: keysToGuards,
      factory: factory,
      heroNet: self)
    return morphism.apply(on: mfddPointer)
  }
  
  /// Count the occurence of each key in an arc
  private func countKeyForAnArc(
    transition: TransitionType,
    place: PlaceType,
    keySet: Set<KeyMFDDVar>)
  -> [KeyMFDDVar: Int] {
    var variableOccurences: [Var: Int] = [:]
    var keyOccurences: [KeyMFDDVar: Int] = [:]
    if let labels = input[transition]?[place] {
        for label in labels {
          switch label {
          case .var(let v):
            if let _ = variableOccurences[v] {
              variableOccurences[v]! += 1
            } else {
              variableOccurences[v] = 1
            }
          default:
            continue
          }
        }
    }
    for key in keySet {
      keyOccurences[key] = variableOccurences[key.label]
    }
    return keyOccurences
  }
  
  /// Construct a first MFDD which represents all enabled bindings without conditions.
  private func constructMFDD(
    placeToKeyToValues: [PlaceType: [KeyMFDDVar: MultisetVal]],
    transition: TransitionType,
    factory: BindingMFDDFactory) -> BindingMFDD.Pointer
  {
    var mfddPointer = factory.one.pointer
    var keySet: Set<KeyMFDDVar> = []
    
    for (_, keyToValues) in placeToKeyToValues {
      for (key, _) in keyToValues {
        keySet.insert(key)
      }
    }
    
    for (place, keyToValues) in placeToKeyToValues {
      let keyOccurences = countKeyForAnArc(transition: transition, place: place, keySet: keySet)
      var keyToValuesWithKeyOccurence: [KeyMFDDVar: (MultisetVal, Int)] = [:]
      keyToValuesWithKeyOccurence = keyToValues.reduce(into: [:], {(res, couple) in
        res[couple.key] = (couple.value, keyOccurences[couple.key]!)
      })
      let mfddTemp = constructMFDD(keyToValuesAndOccurences: keyToValuesWithKeyOccurence, factory: factory)
      // Apply the homomorphism
      mfddPointer = factory.concatAndFilterInclude(mfddPointer, mfddTemp)
    }
    return mfddPointer
  }
  
  
  /// Creates a MFDD pointer that represents all possibilities for a place without guards
  /// The MFDD is specific for a place.
  /// - Parameters:
  ///   - keyToValuesAndOccurences: A dictionnary that binds a key to a tuple where the first argument is possible values, and the secondis the occurence of the key variable on the arc.
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args for a place.
  private func constructMFDD(
    keyToValuesAndOccurences: [KeyMFDDVar: (MultisetVal, Int)],
    factory: BindingMFDDFactory
  ) -> BindingMFDD.Pointer {
    
    if keyToValuesAndOccurences.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, (values, n)) = keyToValuesAndOccurences.sorted(by: {$0.key < $1.key}).first {
      var take: [Val: BindingMFDD.Pointer] = [:]
      var keyToExprsFirstDrop = keyToValuesAndOccurences
      keyToExprsFirstDrop.removeValue(forKey: key)
      
      for el in values {
        // Check we have enough element in values
        if values.occurences(of: el) >= n {
          take[el] = constructMFDD(
            keyToValuesAndOccurences: keyToExprsFirstDrop.reduce(into: [:], {(res, couple) in
              var coupleTemp = couple
              coupleTemp.value.0.remove(el, occurences: n)
              res[couple.key] = coupleTemp.value
            }),
            factory: factory
          )
        }
      }
      return factory.node(key: key, take: take, skip: factory.zero.pointer)
    }
    return factory.zero.pointer
  }

  
  /// Compute a weight for each variable using the guards. The higher a weight is, stronger the dependencies are.
  /// In Decision diagram, the key ordering is a real issue and can dramatically change the performance of the construction of a decision diagram.
  /// The problem is know to be NP-Complete. We use a handmade formula where the goal is to penalize guards where there are a lot of variables.
  /// The more variable there are in a guard, the more the variable inside the guard are impacted. The higher the weight is, the less we are interested in the variable.
  /// Here the formula:
  /// ∀ x ∈ Var, score(x) = ∑_{t ∈ Transition} 2^{nbVar(t) - 1} !
  ///
  /// - Parameters:
  ///   - variableSet: Set of variables
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds each variable to its weight
  func computeWeightScores(
    variableSet: Set<Var>,
    conditions: [Guard]?)
  -> [Var: Int]? {
    
    // If there is no conditions
    guard let _ = conditions else {
      return nil
    }
    var variableWeights: [Var: Int] = [:]
    var variableForACond: [Guard: Set<Var>] = [:]
    var variableInACond: Set<Var> = []
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment its n value, allowing to distingue them
    for variable in variableSet {
      variableWeights[variable] = 0
    }
    
    
    // To know condition variables
    for condition in conditions! {
      for variable in variableSet {
        switch (condition.l, condition.r) {
        case (.var(let v), _):
          if variable == v {
            variableInACond.insert(variable)
          }
        case (_, .var(let v)):
          if variable == v {
            variableInACond.insert(variable)
          }
        case (.exp(let e), _):
          if e.contains(variable) {
            variableInACond.insert(variable)
          }
        case (_, .exp(let e)):
          if e.contains(variable) {
            variableInACond.insert(variable)
          }
        default:
          continue
        }
      }
      
      variableForACond[condition] = variableInACond
      variableInACond = []
    }
    
    // ∀ x ∈ Var, score(x) = ∑_{t ∈ Transition} 2^{nbVar(t) - 1}
    //    let x = 2 << 0    // 2
    //    let y = 2 << 1    // 4
    //    let z = 2 << 7    // 256
    for (_, vars) in variableForACond {
      let nbVar = vars.count
      for v in vars {
        variableWeights[v]! += 2 << nbVar - 1
      }
    }
    
    return variableWeights
  }
  
  // createOrder creates a list of pair from a list of string
  // to represent a total order relation. Pair(l,r) => l < r
  func createTotalOrder(variables: [Var]) -> [Pair<Var, Var>] {
      var r: [Pair<Var, Var>] = []
      for i in 0 ..< variables.count {
        for j in i+1 ..< variables.count {
          r.append(Pair(variables[i],variables[j]))
        }
      }
      return r
  }
  
  // --------------------------------------------------------------------------------- //
  // -------------------------- End of Functions for MFDD ---------------------------- //
  // --------------------------------------------------------------------------------- //

  // --------------------------------------------------------------------------------- //
  // ------------------------------ General functions -------------------------------- //
  // --------------------------------------------------------------------------------- //
  
  /// Create a set of all variables that are implied in a transition
  func createSetOfVariableLabel(
    transition: TransitionType)
  -> Set<Var> {
    var labelSet: Set<Var> = []
    
    // Construct labelList by looking at on arcs
    if let pre = input[transition] {
      for (_, labels) in pre {
        for label in labels {
          switch label {
          case .var(let v):
            labelSet.insert(v)
          default:
            continue
          }
        }
      }
    }
    return labelSet
  }
  
}


extension HeroNet where PlaceType: Comparable {
  
  /// Version with a marking mfdd as input
  public func computeEnabledBindings(
    for transition: TransitionType,
    marking: MFDD<PlaceType, PlaceType.Content>,
    bindingMFDDFactory: BindingMFDDFactory,
    markingMFDDFactory: MarkingMFDDFactory)
  -> BindingMFDD {
    
//    let keySet = createKeys(transition: transition)
//    let dependentKeys = computeDependentKeys(transition: transition, keySet: keySet)
//
//    let (dependentPlaceToKeyToValues, independentKeyToValues) = computeDependentAndIndependentKeyValues(keySet: keySet, dependentKeys: dependentKeys, marking: marking, transition: transition)

    var morphisms: MFDDMorphismFactory<PlaceType, PlaceType.Content> { markingMFDDFactory.morphisms }
    var markingWithoutConstant: MarkingMFDD = marking
    
    var labs: [Var] = []
    var labsTemp: [Var] = []
    var placeToVarWithUniqueVar: [(place: PlaceType, vars: [Var])] = []
    
    if let pre = input[transition] {
      for (place, labels) in pre.sorted(by: {$0.key < $1.key}) {
        for label in labels {
          switch label {
          case .var(let varName):
            if !labs.contains(varName) {
              labs.append(varName)
              labsTemp.append(varName)
            }
          case .val(let val):
            // Apply a pre homomorphism on the constant on the arcs
            let filterMorphism = morphisms.filterMarking(include: (place, val))
            let removeMorphism = morphisms.removeValueInMarking(assignment: (place,val))
            let preMorphism = morphisms.composition(of: removeMorphism, with: filterMorphism)
            markingWithoutConstant = preMorphism.apply(on: markingWithoutConstant)
          case .exp(_):
            fatalError("Expressions are not allowed on the pre arcs.")
          }
        }
        placeToVarWithUniqueVar.append((place: place, vars: labsTemp))
        labsTemp = []
      }
    }
        
    let totalOrder = createTotalOrder(variables: labs)
//    var keys: Set<KeyMFDDVar> = []
//    for lab in labs {
//      keys.insert(KeyMFDDVar(label: lab, couple: totalOrder))
//    }
    
    var placeToKeyWithUniqueKey: [(place: PlaceType, keys: [KeyMFDDVar])] = []
    var keysTemp: [KeyMFDDVar] = []
    for (place, vars) in placeToVarWithUniqueVar {
      for var_ in vars {
        keysTemp.append(KeyMFDDVar(label: var_, couple: totalOrder))
      }
      placeToKeyWithUniqueKey.append((place: place, keys: keysTemp))
      keysTemp = []
    }

    
    var mfddPointer = constructBindings(
      placeToKeyWithUniqueKey: placeToKeyWithUniqueKey,
      marking: markingWithoutConstant,
      transition: transition,
      bindingMFDDFactory: bindingMFDDFactory,
      markingMFDDFactory: markingMFDDFactory)

    // If there are conditions, we have to apply them on the MFDD
//    if let conditions = guards[transition] {
//      let keysToGuards = createKeysToGuards(transition: transition, keySet: keys)
//      // Apply guards
//      mfddPointer = applyCondition(
//        mfddPointer: mfddPointer,
//        guards: conditions,
//        keysToGuards: keysToGuards,
//        // CARRRRRREEEE, that was dependentKeys before
//        dependentKeys: keys,
//        factory: bindingMFDDFactory
//      )
//    }

    // Add independent labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
//    mfddPointer = addIndependentLabel(mfddPointer: mfddPointer, independentKeyToValues: independentKeyToValues, factory: factory)
//    return MFDD(pointer: mfddPointer, factory: bindingMFDDFactory)
    return mfddPointer
  }
  
  func constructBindings(
    placeToKeyWithUniqueKey: [(place: PlaceType, keys: [KeyMFDDVar])],
    marking: MarkingMFDD,
    transition: TransitionType,
    bindingMFDDFactory: BindingMFDDFactory,
    markingMFDDFactory: MarkingMFDDFactory
  ) -> BindingMFDD {
    
    print(placeToKeyWithUniqueKey)
    
    return BindingMFDD(
      pointer: constructBindings(
        placeToKeys: placeToKeyWithUniqueKey,
        markingPointer: marking.pointer,
        transition: transition,
        bindingMFDDFactory: bindingMFDDFactory,
        markingMFDDFactory: markingMFDDFactory
      ),
      factory: bindingMFDDFactory
    )
    
  }
  
  
  func constructBindings(
    placeToKeys: [(place: PlaceType, keys: [KeyMFDDVar])],
    markingPointer: MarkingMFDD.Pointer,
    transition: TransitionType,
    bindingMFDDFactory: BindingMFDDFactory,
    markingMFDDFactory: MarkingMFDDFactory
  )
  -> BindingMFDD.Pointer {
    
    if placeToKeys.isEmpty {
      return bindingMFDDFactory.one.pointer
    }
    
    if markingPointer == markingMFDDFactory.one.pointer || markingPointer == markingMFDDFactory.zero.pointer {
      return bindingMFDDFactory.zero.pointer
    }
    
    if let pToK = placeToKeys.first {
      var resTemp: BindingMFDD.Pointer = bindingMFDDFactory.zero.pointer
      var resPointer: BindingMFDD.Pointer = bindingMFDDFactory.zero.pointer
      
      if markingPointer.pointee.key < pToK.place {
        print(markingPointer.pointee.key)
        for (_, markingPointer) in markingPointer.pointee.take {
          
          resTemp = constructBindings(
            placeToKeys: placeToKeys,
            markingPointer: markingPointer,
            transition: transition,
            bindingMFDDFactory: bindingMFDDFactory,
            markingMFDDFactory: markingMFDDFactory
          )
          
          // TODO: CHANGE THIS HORROR
          resPointer = BindingMFDD(pointer: resPointer, factory: bindingMFDDFactory).union(BindingMFDD(pointer: resTemp, factory: bindingMFDDFactory)).pointer
        }
      } else if markingPointer.pointee.key == pToK.place {
        var bindTemp: BindingMFDD.Pointer = bindingMFDDFactory.zero.pointer
        var initPointer: BindingMFDD.Pointer = bindingMFDDFactory.zero.pointer
        for (multiset, subMarkingPointer) in markingPointer.pointee.take {
          initPointer = constructBindings(
            placeToKeys: Array(placeToKeys.dropFirst()),
            markingPointer: subMarkingPointer,
            transition: transition,
            bindingMFDDFactory: bindingMFDDFactory,
            markingMFDDFactory: markingMFDDFactory
          )
          bindTemp = constructBindingForAPlace(multiset: multiset, keyList: pToK.keys, initPointer: initPointer, bindingMFDDFactory: bindingMFDDFactory)
          resPointer = BindingMFDD(pointer: resPointer, factory: bindingMFDDFactory).union(BindingMFDD(pointer: bindTemp, factory: bindingMFDDFactory)).pointer
        }
        
        return resPointer

      }

    }
    
    return bindingMFDDFactory.zero.pointer
  }
  
  func constructBindingForAPlace(
    multiset: PlaceType.Content,
    keyList: [KeyMFDDVar],
    initPointer: BindingMFDD.Pointer,
    bindingMFDDFactory: BindingMFDDFactory
  ) -> BindingMFDD.Pointer {
    
    if keyList.isEmpty {
      return initPointer
    }
    
    if let firstKey = keyList.first {
      var take: [PlaceType.Content.Key: BindingMFDD.Pointer] = [:]
      var multisetTemp = multiset
      var pointerTemp: BindingMFDD.Pointer = bindingMFDDFactory.zero.pointer
      for val in multiset {
        multisetTemp.remove(val)
        pointerTemp = constructBindingForAPlace(
          multiset: multisetTemp,
          keyList: Array(keyList.dropFirst()),
          initPointer: initPointer,
          bindingMFDDFactory: bindingMFDDFactory
        )
        take[val] = pointerTemp
        multisetTemp = multiset
      }
      
      return bindingMFDDFactory.node(key: firstKey, take: take, skip: bindingMFDDFactory.zero.pointer)
    }
    
    return bindingMFDDFactory.zero.pointer
  }
  
}
