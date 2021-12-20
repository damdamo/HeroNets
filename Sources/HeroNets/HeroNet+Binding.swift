import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  public typealias KeyMFDDVar = KeyMFDD<Var>
  public typealias HeroMFDD = MFDD<KeyMFDDVar, Val>
  public typealias HeroMFDDFactory = MFDDFactory<KeyMFDDVar, Val>
    
  /// Compute the whole binding for a transition and a marking. The binding represents all possibilities of values for each variable that satisfied the conditions of the net (i.e.: Guards, same label name multiple times). It creates a MFDD (Map family decision diagram) which is a compact implicit representation based on the theory on DD (Decision diagrams).
  /// A factory has to be created outside the scope that allows to manage the DD efficiently. (e.g.: `let factory = MFDDFactory<KeyMFDDLabel,ValueMFDD>()`
  /// To reduce the complexity of the net, multiple steps are processed before the creation of the MFDD.
  /// There are two main steps of optimizations.
  /// - Static optimization: Based on the structure of the net, it does not depend on the marking. It will compute a new net based on it.
  /// - Dynamic optimization: Based on structure and/or the marking, it modifies the structure and the current marking.
  /// Once time it is done, the computation of the MFDD can start. MFDD takes advantage of homorphisms to apply operations directly on the compact representation, instead of working on a naive representation with sets.
  /// - Parameters:
  ///   - for transition: The transition to compute bindings
  ///   - with marking: The marking to use
  ///   - factory: The factory needed to work on MFDD
  /// - Returns:
  ///   Returns all bindings for a specific transition and a marking
  public func fireableBindings(for transition: TransitionType, with marking: Marking<PlaceType>, factory: HeroMFDDFactory) -> HeroMFDD {
    
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = computeStaticOptimizedNet()
    
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = staticOptimizedNet.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    
    if let (dynamicOptimizedNet, newMarking) = tupleDynamicOptimizedNetAndnewMarking {
      return dynamicOptimizedNet.fireableBindings(for: transition, marking: newMarking, factory: factory)
    }
    
    return factory.zero
  }
  
  /// Same method as fireableBindings, however there is no static optimization  here.
  /// When the state space computation is performed, the static optimization is realized before to avoid unecessary computations.
  func fireableBindingsForCSS(for transition: TransitionType, with marking: Marking<PlaceType>, factory: HeroMFDDFactory) -> HeroMFDD {
    
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = self.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    
    if let (dynamicOptimizedNet, newMarking) = tupleDynamicOptimizedNetAndnewMarking {
      return dynamicOptimizedNet.fireableBindings(for: transition, marking: newMarking, factory: factory)
    }
    
    return factory.zero
  }

  
  
  // --------------------------------------------------------------------------------- //
  // ----------------------- Functions for static optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
  
  /// Takes the input net and optimizes it to get an optimize version if possible. It uses the information on guard to shift certain conditions such as equality variable or a constant expression equal to a variable on the structure and removes the condition.
  /// This is a purely static optimization that is applied on the structure, it does not depend on the marking.
  /// - Returns:
  ///   Returns an optimized net
  public func computeStaticOptimizedNet() -> HeroNet {
    
    var netOptimized = self
    for transition in TransitionType.allCases {
      netOptimized = netOptimized.constantPropagationVariable(transition: transition)
      netOptimized = netOptimized.constantPropagationValue(transition: transition)
    }
    return netOptimized
  }
  
  /// The constant propagation optimization uses guard of the form "x = constant expression" to replace all occurences of x by the constant expression in every possible expressions (e.g.: arcs, guards)
  /// - Parameters:
  ///   - net:The net that is optimized
  ///   - transition: The current transition
  /// - Returns:
  ///  Returns a new net where constant propagation is applied
  private func constantPropagationValue(transition: TransitionType) -> HeroNet {
    
    let labelSet = createSetOfVariableLabel(transition: transition)
    
    if let conditions = guards[transition] {
      // Isolate condition with a unique variable
      let (constantLabels, condRest) = getConstantLabels(labelSet: labelSet, conditions: conditions)
      

      // We do not keep condition with a unique label in the future net !
      var guardsTemp = guards
      guardsTemp[transition] = condRest
      let netTemp = HeroNet(input: input, output: output, guards: guardsTemp, interpreter: interpreter)
      return replaceVarsForATransition(varToValue: constantLabels, transition: transition, net: netTemp)
      
    }
    return self
  }
  
  /// A general function to replace all occurence of a label by a certain **value**. It looks at every arcs and guards.
  /// - Parameters:
  ///   - labelToValue: A dictionnary that binds every labels to their new value (or variable)
  ///   - transition: The current transition
  ///   - net:The net that is optimized
  /// - Returns:
  ///  Returns a new net where label has been replaced by new values
  public func replaceVarsForATransition(varToValue: [Var: Val], transition: TransitionType, net: HeroNet) -> HeroNet {
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
  
  /// A general function to replace all occurence of a label by a certain **variable**. It looks at every arcs and guards.
  /// - Parameters:
  ///   - labelToValue: A dictionnary that binds every labels to their new value (or variable)
  ///   - transition: The current transition
  ///   - net:The net that is optimized
  /// - Returns:
  ///  Returns a new net where label has been replaced by new values
  public func replaceVarsForATransition(varToVar: [Var: Var], transition: TransitionType, net: HeroNet) -> HeroNet {
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
  /// - Parameters:
  ///   - transition: The transition that is looking at
  /// - Returns:
  ///  Returns a new net where the equality in guard optimization is applied
  private func constantPropagationVariable(transition: TransitionType) -> HeroNet {
    // Equality guards
    let equivalentVariables  = createDicOfEquivalentLabel(transition: transition)
    
    return replaceVarsForATransition(varToVar: equivalentVariables, transition: transition, net: self)
  }
  
  /// Creates a dictionnary from the equivalent label that binds a label to its new name. It means that if we have a condition of the form " x = y", a new entry will be added in the dictionnary (e.g.: [x:y]). At the end this dictionnary will  be used to know which labels has to be replaced.
  /// - Parameters:
  ///   - transition: The transition that is looking at
  /// - Returns:
  ///  Returns a dictionnary of label to label where the key is the old name of the label and the value its new name
  private func createDicOfEquivalentLabel(transition: TransitionType) -> [Var: Var] {
    
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
  
  /// Isolate conditions with a unique label (only one)
  /// - Parameters:
  ///   - LabelSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  private func getConstantLabels(labelSet: Set<Var>, conditions: [Guard]?)
  -> (constantLabels: [Var: Val], restGuards: [Guard]) {

    var constantLabels: [Var: Val] = [:]
    var restGuards: [Guard] = []
    
    if let conds = conditions {
      for cond in conds {
        switch (cond.l, cond.r) {
        case (.var(let v), .val(let val)):
          guard let _ = constantLabels[v] else {
            fatalError("A constant is assigned more than two times to the same variable")
          }
          constantLabels[v] = val
        case (.val(let val), .var(let v)):
          guard let _ = constantLabels[v] else {
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
    marking: Marking<PlaceType>) -> (HeroNet, Marking<PlaceType>)?
  {
    // Optimizations on constant on arcs, removing it from the net and from the marking in  the place
    if let (netWithoutConstant, markingWithoutConstant) = consumeConstantOnArcs(transition: transition, marking: marking) {
      return (netWithoutConstant, markingWithoutConstant)
    }
    return nil
  }
  
  /// During the firing, consume directly the constant into the marking before starting the computation
  public func consumeConstantOnArcs(
    transition: TransitionType,
    marking: Marking<PlaceType>) -> (HeroNet, Marking<PlaceType>)?
  {
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
  
  
  /// Compute possible values for labels of each place
  /// - Parameters:
  ///   - transition: The current transition
  ///   - marking: The current marking
  /// - Returns:
  ///   Returns a dictionnary that binds each  place to its labels and their possible values
  private func computeValuesForLabel(transition: TransitionType, marking: Marking<PlaceType>)
  -> [PlaceType: [Var: MultisetVal]]
  {
    var placeToLabelToValues: [PlaceType: [Var: MultisetVal]] = [:]
    
    if let pre = input[transition] {
      for (place, labels) in pre {
        placeToLabelToValues[place] = [:]
        for label in labels {
          switch label {
          case .var(let v):
            placeToLabelToValues[place]![v] = marking[place]
          default:
            continue
          }
        }
      }
    }
    
    return placeToLabelToValues
  }
  
  
  // --------------------------------------------------------------------------------- //
  // ------------------- End of functions for dynamic optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ----------------------------- Functions for MFDD -------------------------------- //
  // --------------------------------------------------------------------------------- //
  
  private func fireableBindings(for transition: TransitionType, marking: Marking<PlaceType>, factory: HeroMFDDFactory) -> HeroMFDD {
    
    let variableSet = createSetOfVariableLabel(transition: transition)
    
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let (labelWeights, conditionWeights) = computeScoreOrder(
      variableSet: variableSet,
      conditions: guards[transition]
    )
    
    let placeToLabelToValues = bindLabelVariablesToValues(transition: transition, marking: marking)
    
    // Check that each labels has at least one possibility
    for (place, dicLabelToValues) in placeToLabelToValues {
      for (label, _) in dicLabelToValues {
        if placeToLabelToValues[place]![label]!.isEmpty {
          return factory.zero
        }
      }
    }
    
    
    // Return the precedent placeToLabelToValues value to the same one where label are now key
    let placeToKeyToValues = fromVariableToKey(variableSet: variableSet, variableWeights: labelWeights, placeToVariableToValues: placeToLabelToValues)

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
      for condition in conditions.sorted(by: {conditionWeights![$0]! > conditionWeights![$1]!}) {
        // Apply guards
        mfddPointer = applyCondition(
          mfddPointer: mfddPointer,
          condition: condition,
          keySet: keySet,
          factory: factory
        )
      }
    }
    
    // Add independent labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
    mfddPointer = addIndependentLabel(mfddPointer: mfddPointer, independentKeyToValues: independentKeyToValues, factory: factory)
    
    return MFDD(pointer: mfddPointer, factory: factory)

  }
  
  private func bindLabelVariablesToValues(
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
  
  /// Transform labels into key in the place to label to values structure.
  /// - Parameters:
  ///   - labelSet: A set containing each label of the net
  ///   - labelWeights: Label weights
  ///   - placeToLabelToValues: The structure to change to pass from label to key
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
        lw[label1]! > lw[label2]!
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
  
  /// Create a dictionnary that keeping information about dependent keys for a  specific transition. A dependent key is a label that appears in a condition or an arc that contains multiple label. For both, we add an entry to dependent keys. The information about the place is kept in the case of a dependent keym which is not the case for a independent key. It is explained by the fact that an independent key appears alone on a single arc and do not altere anything in the binding computation.
  /// - Parameters:
  ///   - placeToKeyToValues: Places that are bound to key which are bound to values
  ///   - transition: The current  transition
  /// - Returns:
  ///   Returns a tuple of two dictionnary, where the first one is for independent keys and the second one for dependent keys.
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
  
  
  /// Takes the current MFDD and adds values for independent keys. It allows to construct the first mfdd with conditions only on variables that can be affected by it, then just adding like a simple concatenation for the rest of values.
  /// Do not need to evaluate anything !
  /// - Parameters:
  ///   - mfddPointer:Current mfdd pointer
  ///   - independentKeyToValues: List of keys with their expressions with no influenced between keys in the net.
  ///   - factory: Current factory
  /// - Returns:
  ///   Returns a new mfdd pointer where values of the independent keys have been added.
  private func addIndependentLabel(mfddPointer: HeroMFDD.Pointer, independentKeyToValues: [KeyMFDDVar: MultisetVal], factory: HeroMFDDFactory) -> HeroMFDD.Pointer {
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
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, values) = keyToExprs.sorted(by: {$0.key < $1.key}).first {
      var take: [Val: HeroMFDD.Pointer] = [:]
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
    mfddPointer: HeroMFDD.Pointer,
    condition: Guard,
    keySet: Set<KeyMFDDVar>,
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    var morphisms: MFDDMorphismFactory<KeyMFDDVar, Val> { factory.morphisms }
    let keyCond = keySet.filter({(key) in
      return contains(exp: condition.l, s: key.label) || contains(exp: condition.r, s: key.label)
    })
    
    let morphism = guardFilter(condition: condition, keyCond: Array(keyCond), factory: factory, heroNet: self)
    
    return morphism.apply(on: mfddPointer)
    
  }
  
  private func countKeyForAnArc(transition: TransitionType, place: PlaceType, keySet: Set<KeyMFDDVar>) -> [KeyMFDDVar: Int] {
   
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
  
  private func constructMFDD(
    placeToKeyToValues: [PlaceType: [KeyMFDDVar: MultisetVal]],
    transition: TransitionType,
    factory: HeroMFDDFactory) -> HeroMFDD.Pointer
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
  ///
  /// - Parameters:
  ///   - keyToValuesAndOccurences: A dictionnary that binds a key to its possible values
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args for a place.
  private func constructMFDD(
    keyToValuesAndOccurences: [KeyMFDDVar: (MultisetVal, Int)],
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToValuesAndOccurences.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, (values, n)) = keyToValuesAndOccurences.sorted(by: {$0.key < $1.key}).first {
      var take: [Val: HeroMFDD.Pointer] = [:]
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

  
  /// Compute a score for each variable using the guards, and the score of priority for each conditions. The score is used to determine the order to apply conditions
  ///
  /// - Parameters:
  ///   - labelSet: Set of labels
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a tuple with its first element a dictionnary that binds a label to its weight and second element a dictionnary that binds condition to a score !
  private func computeScoreOrder(
    variableSet: Set<Var>,
    conditions: [Guard]?)
  -> ([Var: Int]?, [Guard: Int]?) {
    
    // If there is no conditions
    guard let _ = conditions else {
      return (nil, nil)
    }
    var variableWeights: [Var: Int] = [:]
    var conditionWeights: [Guard: Int] = [:]
    var variableForACond: [Set<Var>] = []
    var variableInACond: Set<Var> = []
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment its n value, allowing to distingue them
    for variable in variableSet {
      variableWeights[variable] = 100
    }
    
    for condition in conditions! {
      conditionWeights[condition] = 100
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
      
      // Compute condition weights
      if variableInACond.count != 0 {
        conditionWeights[condition]! *= 2/variableInACond.count
      } else {
        conditionWeights[condition]! = 0
      }
      
      variableForACond.append(variableInACond)
      variableInACond = []
    }
    
    // To compute a score
    // If a condition contains the same variable, it earns 50 points
    // If a condition contains a variable with other variables, every variables earn 10 points
    for (variable, _) in variableWeights {
      for cond in variableForACond {
        if cond.contains(variable) {
          if cond.count == 1  {
            variableWeights[variable]! += 100
          } else {
            variableWeights[variable]! += 10
          }
        }
      }
    }
    
    return (variableWeights, conditionWeights)
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
  
  // TODO: CARE if it's not
  public func createSetOfVariableLabel(transition: TransitionType) -> Set<Var> {
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


