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
    factory: BindingMFDDFactory)
  -> BindingMFDD {
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = computeStaticOptimizedNet()
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = staticOptimizedNet.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    if let (dynamicOptimizedNet, newMarking) = tupleDynamicOptimizedNetAndnewMarking {
      return dynamicOptimizedNet.computeEnabledBindings(for: transition, marking: newMarking, factory: factory)
    }
    return factory.zero
  }
  
  /// Same method as fireableBindings, however there is no static optimization  here.
  /// When the state space computation is performed, the static optimization is realized before to avoid unecessary computations.
  func fireableBindingsForCSS(
    for transition: TransitionType,
    with marking: Marking<PlaceType>,
    factory: BindingMFDDFactory)
  -> BindingMFDD {
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = self.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
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
          case .exp(let e):
            newOutput[transition]![place]!
              .insert(bindVariables(expr: .exp(e), binding: varToValue))
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
    let variableSet = createSetOfVariableLabel(transition: transition)
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let varWeights = computeWeightScores(
      variableSet: variableSet,
      conditions: guards[transition]
    )
    print(varWeights)
    let placeToLabelToValues = bindVariablesToValues(transition: transition, marking: marking)
    // Check that each labels has at least one possibility
    for (place, dicLabelToValues) in placeToLabelToValues {
      for (label, _) in dicLabelToValues {
        if placeToLabelToValues[place]![label]!.isEmpty {
          return factory.zero
        }
      }
    }
    // Return the precedent placeToLabelToValues value to the same one where label are now key
    let placeToKeyToValues = fromVariableToKey(variableSet: variableSet, variableWeights: varWeights, placeToVariableToValues: placeToLabelToValues)
    // Isolate dependent and independent keys
    let (dependentPlaceToKeyToValues, independentKeyToValues) = computeDependentAndIndependentKeys(placeToKeyToValues: placeToKeyToValues, transition: transition)
    var mfddPointer = constructMFDD(placeToKeyToValues: dependentPlaceToKeyToValues, transition:transition, factory: factory)
    
    // If there are conditions, we have to apply them on the MFDD
    if let conditions = guards[transition] {
      var keySet: Set<KeyMFDDVar> = []
      for (_, keyToValues) in dependentPlaceToKeyToValues {
        for (key, _) in keyToValues {
          keySet.insert(key)
        }
      }
      var keysToGuards: [Set<KeyMFDDVar>: Set<Guard>] = [:]
      var keys: Set<KeyMFDDVar>
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
      // Apply guards
      mfddPointer = applyCondition(
        mfddPointer: mfddPointer,
        guards: conditions,
        keysToGuards: keysToGuards,
        keySet: keySet,
        factory: factory
      )
    }
    // Add independent labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
    mfddPointer = addIndependentLabel(mfddPointer: mfddPointer, independentKeyToValues: independentKeyToValues, factory: factory)
    return MFDD(pointer: mfddPointer, factory: factory)
  }
  
  /// Bind each variable on arcs to all possible values from the marking.
  private func bindVariablesToValues(
    transition: TransitionType,
    marking: Marking<PlaceType>
  ) -> [PlaceType: [Var: MultisetVal]] {
    
    var res: [PlaceType: [Var: MultisetVal]] = [:]
    if let dicPlaceToLabel = input[transition] {
      for (place, labels) in dicPlaceToLabel {
        res[place] = [:]
        for label in labels {
          switch label {
          case .var(let v):
            res[place]![v] = marking[place]
          default:
            continue
          }
        }
      }
      return res
    }
    return [:]
  }
  
  /// Transform variables into keys in the original type: [PlaceType: [Var: MultisetVal]].
  /// In addition, it uses the weights of variables to create the key order (to give a total order).
  /// - Parameters:
  ///   - variableSet: A set containing each label of the net
  ///   - variableWeights: Label weights
  ///   - placeToVariableToValues: The structure to change to pass from label to key
  /// - Returns:
  ///   Returns a dictionnary that binds each place to its key with their corresponding values
  private func fromVariableToKey (
    variableSet: Set<Var>,
    variableWeights: [Var: Int]?,
    placeToVariableToValues: [PlaceType: [Var: MultisetVal]]
  ) -> [PlaceType: [KeyMFDDVar: MultisetVal]] {

    let totalOrder: [Pair<Var, Var>]
    var placeToKeyToValues: [PlaceType: [KeyMFDDVar: MultisetVal]] = [:]
    
    if let lw = variableWeights {
      totalOrder = createTotalOrder(variables: variableSet.sorted(by: {(label1, label2) -> Bool in
        lw[label1]! < lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(variables: Array(variableSet))
    }
    
    for (place, labelToValues) in placeToVariableToValues {
      placeToKeyToValues[place] = [:]
      for (label, values) in labelToValues {
        let key = KeyMFDDVar(label: label, couple: totalOrder)
        placeToKeyToValues[place]![key] = values
      }
    }

    return placeToKeyToValues
  }
  
  /// Dependent keys are keys where the corresponding variable is either in a condition, or in an arc with multiple variable.
  /// Independent keys are the rest.
  /// The dissociation is important cause independent keys can be just added in the MFDD, because every values for the following key can be chosen without any impact on the firing. Every values will be valid.
  /// - Parameters:
  ///   - placeToKeyToValues: Places that are bound to key which are bound to values
  ///   - transition: The current  transition
  /// - Returns:
  ///   Returns a tuple of two dictionnary, where the first one is for dependent keys and the second one for independent keys.
  private func computeDependentAndIndependentKeys(
    placeToKeyToValues: [PlaceType: [KeyMFDDVar: MultisetVal]],
    transition: TransitionType)
  -> ([PlaceType: [KeyMFDDVar: MultisetVal]], [KeyMFDDVar: MultisetVal]) {

    var independentKeysToValues: [KeyMFDDVar: MultisetVal] = [:]
    var placeToDependentKeysToValues: [PlaceType: [KeyMFDDVar: MultisetVal]] = [:]
    var setKeys: Set<KeyMFDDVar> = []
    var dependentKeys: Set<KeyMFDDVar> = []
    
    // Construct set of keys
    for (_, keyToValues) in placeToKeyToValues {
      for (key, _) in keyToValues {
        setKeys.insert(key)
      }
    }
    
    if let conditions = guards[transition] {
      for condition in conditions {
        for key in setKeys {
          switch (condition.l, condition.r) {
          case (.var(let v), _):
            if key.label == v {
              dependentKeys.insert(key)
            }
          case (_, .var(let v)):
            if key.label == v {
              dependentKeys.insert(key)
            }
          case (.exp(let e), _):
            if e.contains(key.label) {
              dependentKeys.insert(key)
            }
          case (_, .exp(let e)):
            if e.contains(key.label) {
              dependentKeys.insert(key)
            }
          default:
            continue
          }
        }
      }
    }
    
    for (place, keyToValues) in placeToKeyToValues {
      if keyToValues.count >= 1 {
        placeToDependentKeysToValues[place] = [:]
        for (key, values) in keyToValues {
          placeToDependentKeysToValues[place]![key] = values
        }
      } else {
        for (key, values) in keyToValues {
          if dependentKeys.contains(key) {
            if placeToDependentKeysToValues[place] == nil {
              placeToDependentKeysToValues[place] = [:]
            }
            placeToDependentKeysToValues[place]![key] = values
          } else {
            independentKeysToValues[key] = values
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
    keySet: Set<KeyMFDDVar>,
    factory: BindingMFDDFactory
  ) -> BindingMFDD.Pointer {
    var morphisms: MFDDMorphismFactory<KeyMFDDVar, Val> { factory.morphisms }
    let morphism = guardFilter(
      keys: keySet,
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
    var mfddPointer = factory.zero.pointer
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
  private func computeWeightScores(
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
  private func createTotalOrder(variables: [Var]) -> [Pair<Var, Var>] {
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


