import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  public typealias KeyMFDDLabel = KeyMFDD<Label>
  public typealias HeroMFDD = MFDD<KeyMFDDLabel,Value>
  public typealias HeroMFDDFactory = MFDDFactory<KeyMFDDLabel,Value>
    
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
  func fireableBindings(for transition: TransitionType, with marking: Marking<PlaceType>, factory: HeroMFDDFactory) -> HeroMFDD {
    
    // Static optimization, only depends on the structure of the net
    let staticOptimizedNet = computeStaticOptimizedNet(transition: transition)
    
    // Dynamic optimization, depends on the structure of the net and the marking
    let tupleDynamicOptimizedNetAndnewMarking = staticOptimizedNet!.computeDynamicOptimizedNet(transition: transition, marking: marking) ?? nil
    
    if let (dynamicOptimizedNet, placeToLabelToValues) = tupleDynamicOptimizedNetAndnewMarking {
      return dynamicOptimizedNet.fireableBindings(for: transition, placeToLabelToValues: placeToLabelToValues, factory: factory)
    }
    
    return factory.zero
  }
  
  
  // --------------------------------------------------------------------------------- //
  // ----------------------- Functions for static optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
  
  /// Takes the input net and optimizes it to get an optimize version if possible. It uses the information on guard to shift certain conditions such as equality variable or a constant expression equal to a variable on the structure and removes the condition.
  /// This is a purely static optimization that is applied on the structure, it does not depend on the marking.
  /// - Parameters:
  ///   - transition: The transition to optimize
  /// - Returns:
  ///   Returns an optimized net
  public func computeStaticOptimizedNet(transition: TransitionType) -> HeroNet? {
    let netConstantPropagationVariable = constantPropagationVariable(transition: transition)
    let netConstantPropagation = constantPropagation(net: netConstantPropagationVariable, transition: transition)
    return netConstantPropagation
  }
  
  /// The constant propagation optimization uses guard of the form "x = constant expression" to replace all occurences of x by the constant expression in every possible expressions (e.g.: arcs, guards)
  /// - Parameters:
  ///   - net:The net that is optimized
  ///   - transition: The current transition
  /// - Returns:
  ///  Returns a new net where constant propagation is applied
  private func constantPropagation(net: HeroNet, transition: TransitionType) -> HeroNet? {
    
    let labelSet = createLabelSet(net: net, transition: transition)
    
    if let conditions = net.guards[transition] {
      // Isolate condition with a unique variable
      let (dicSameLabelToCondition, condRest) = isolateCondWithUniqueLabel(labelSet: labelSet, conditions: conditions)
      
      if let labelToConstant = createDicOfConstantLabel(dicUniqueLabelToCondition: dicSameLabelToCondition) {
        // We do not keep condition with a unique label in the future net !
        var guardsTemp = net.guards
        guardsTemp[transition] = condRest
        let netTemp = HeroNet(input: net.input, output: net.output, guards: guardsTemp, interpreter: interpreter)
        return replaceLabelsForATransition(labelToValue: labelToConstant, transition: transition, net: netTemp)
      }
      return nil
    }
    return net
  }
  
  /// A general function to replace all occurence of a label by a certain value or variable. It looks at every arcs and guards.
  /// - Parameters:
  ///   - labelToValue: A dictionnary that binds every labels to their new value (or variable)
  ///   - transition: The current transition
  ///   - net:The net that is optimized
  /// - Returns:
  ///  Returns a new net where label has been replaced by new values
  private func replaceLabelsForATransition(labelToValue: [Label: Value], transition: TransitionType, net: HeroNet) -> HeroNet {
    var newInput = net.input
    var newOutput = net.output
    var newGuards = net.guards
    
    if let pre = newInput[transition] {
      for (place, labels) in pre {
        newInput[transition]![place] = labels.map({(label) in
          if let newLabel = labelToValue[label] {
            return newLabel
          } else {
            return label
          }
        })
      }
    }
    
    if let post = newOutput[transition] {
      for (place, labels) in post {
        newOutput[transition]![place] = labels.map({(label) in
          if let newLabel = labelToValue[label] {
            return newLabel
          } else {
            return label
          }
        })
      }
    }
    
    if let _ = guards[transition] {
      newGuards[transition] = newGuards[transition]!.compactMap({(pair) in
        var l = pair.l
        var r = pair.r
        for (key, value) in labelToValue {
          l = l.replacingOccurrences(of: key, with: value)
          r = r.replacingOccurrences(of: key, with: value)
        }
        if l == r {
          return nil
        }
        return Pair(l,r)
      })
    }
        
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, interpreter: interpreter)
  }
  
  /// Takes a dictionnary of label binds to condition with a unique variable, then evaluates each condition to have a value for each expression.
  /// Each label is associated to a value.
  /// - Parameters:
  ///   - dicUniqueLabelToCondition: The dictionnary that binds label to a list of conditions which are already in the good format (i.e.: var == a constant expression)
  /// - Returns:
  ///  Returns a new dictionnary of label to values, where each previous expressions has been evaluated
  private func createDicOfConstantLabel(dicUniqueLabelToCondition: [Label: [Pair<Value, Value>]]) -> [Label: Value]? {
    
    var constantCondition: [Label: Value] = [:]
    
    for (label, conditionList) in dicUniqueLabelToCondition {
      for condition in conditionList {
        var value: Value = ""
        if condition.l == label {
          value = eval(condition.r)
        } else {
          value = eval(condition.l)
        }
        if let val = constantCondition[label] {
          // Two conditions with different constant value
          if val != value {
            return nil
          }
        } else {
          constantCondition[label] = value
        }
      }
    }
    
    return constantCondition
  }
  
  /// Optimization function that takes conditions of the form "x = y" and replaces each occurence of x by y in the net. Then, it removes the condition.
  /// - Parameters:
  ///   - transition: The transition that is looking at
  /// - Returns:
  ///  Returns a new net where the equality in guard optimization is applied
  private func constantPropagationVariable(transition: TransitionType) -> HeroNet {
    // Equality guards
    let equivalentVariables  = createDicOfEquivalentLabel(transition: transition)
    
    return replaceLabelsForATransition(labelToValue: equivalentVariables, transition: transition, net: self)
  }
  
  /// Creates a dictionnary from the equivalent label that binds a label to its new name. It means that if we have a condition of the form " x = y", a new entry will be added in the dictionnary (e.g.: [x:y]). At the end this dictionnary will  be used to know which labels has to be replaced.
  /// - Parameters:
  ///   - transition: The transition that is looking at
  /// - Returns:
  ///  Returns a dictionnary of label to label where the key is the old name of the label and the value its new name
  private func createDicOfEquivalentLabel(transition: TransitionType) -> [Label: Label] {
    
    guard let _ = guards[transition] else { return [:] }
    
    let labelSet = createLabelSet(net: self, transition: transition)
    
    var eqLabelList: [Pair<Label, Label>] = []
    
    // Construct a list of equal label coming from the conditions
    if let conditions = guards[transition] {
      for condition in conditions {
        if labelSet.contains(condition.l) && labelSet.contains(condition.r) {
          eqLabelList.append(Pair(condition.l, condition.r))
        }
      }
    }
    
    var eqLabelDic: [Label: Label] = [:]
    
    // Construct the dictionnary that binds label to its renaming label
    while !eqLabelList.isEmpty {
      if let firstPairOfLabel = eqLabelList.first {
        eqLabelList.remove(at: 0)
        if eqLabelDic.contains(where: {$0.key == firstPairOfLabel.l}) {
          for (key, value) in eqLabelDic {
            if value == firstPairOfLabel.l {
              eqLabelDic[key] = firstPairOfLabel.r
            }
          }
          eqLabelDic[firstPairOfLabel.l] = firstPairOfLabel.r
        } else {
          eqLabelDic[firstPairOfLabel.l] = firstPairOfLabel.r
        }
      }
    }
    
    return eqLabelDic
  }
  
  /// Isolate conditions with the same variable to apply
  /// - Parameters:
  ///   - LabelSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  private func isolateCondWithUniqueLabel(labelSet: Set<Label>, conditions: [Pair<Value, Value>]?) -> ([Label: [Pair<Value, Value>]], [Pair<Value,Value>]) {

    var condWithUniqueVariable: [Label: [Pair<Value, Value>]] = [:]
    var restConditions: [Pair<Value, Value>] = []

    if let conds = conditions {
      for cond in conds {
        if labelSet.contains(cond.l) {
          if !cond.r.contains("$") {
            if let _ = condWithUniqueVariable[cond.l] {
              condWithUniqueVariable[cond.l]!.append(cond)
            } else {
              condWithUniqueVariable[cond.l] = [cond]
            }
          } else {
            restConditions.append(cond)
          }
        } else if labelSet.contains(cond.r) {
          if !cond.l.contains("$") {
            if let _ = condWithUniqueVariable[cond.r] {
              condWithUniqueVariable[cond.r]!.append(cond)
            } else {
              condWithUniqueVariable[cond.r] = [cond]
            }
          } else {
            restConditions.append(cond)
          }
        } else {
          restConditions.append(cond)
        }
      }
    }
    return (condWithUniqueVariable, restConditions)

  }
  
  // --------------------------------------------------------------------------------- //
  // -------------------- End of functions for static optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ---------------------- Functions for dynamic optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
  /// Computes dynamic optimizations on the net and constructs dictionnary that binds place to their labels and their corresponding values
  /// Thereare three dynamics optimizations:
  /// - Remove constant on arcs: Remove the constant on the arc and remove it into the marking
  /// - Optimize guard with same label: If a condition has the same variable, the possible values for this label will be tested to keep only which are satisfied. Moreover, it deletes the condition
  /// - Optimize same label on arcs: If different arcs have the same label, we apply a kind of intersection to keep only values that are possibles for both arcs.
  /// - Parameters:
  ///   - transition: The current transition
  ///   - marking: The current marking
  /// - Returns:
  ///   Returns a new net modify with the optimizations and a dictionnary that contains for each place, possible values for labels
  private func computeDynamicOptimizedNet(
    transition: TransitionType,
    marking: Marking<PlaceType>) -> (HeroNet, [PlaceType: [Label: Multiset<Value>]])?
  {
    
    // Dynamic optimizations that modify the structure and the marking
    
    // Optimizations on constant on arcs, removing it from the net and from the marking in  the place
    if let (netWithoutConstant, markingWithoutConstant) = removeConstantOnArcs(transition: transition, marking: marking) {
      // Transform the marking into a more complete structure that says how many values are available for each label of each place
      let placeToLabelToValues = netWithoutConstant.computeValuesForLabel(transition: transition, marking: markingWithoutConstant)
      // Filter condition with the same variable that are more complex than just x = constant (e.g.:  x%2 = 0).
      // Remove the conditions and keep values that satisfie these kind of conditions.
      
      // If there is no value for a label, it means there are no valid bindings
      for (_, labelToValues) in placeToLabelToValues {
        for (_, values) in labelToValues {
          if values.isEmpty {
            return nil
          }
        }
      }
     return optimizedGuardWithSameLabel(transition: transition, placeToLabelToValues: placeToLabelToValues)

    }
    
    return nil
  }
  
  private func removeConstantOnArcs(
    transition: TransitionType,
    marking: Marking<PlaceType>) -> (HeroNet, Marking<PlaceType>)?
  {

    var newMarking = marking
    var newInput = input
    
    if let pre = input[transition] {
      for (place, labels) in pre {
        for label in labels {
          if !label.contains("$") {
            // The content of the place is subtracted by the value of the constant
            // If the condition is not satisfied, it means the marking does not contain the constant
            if newMarking[place].occurences(of: label) > 0 {
              newMarking[place].remove(label)
            } else {
              return nil
            }
            // The constant label is removed
            newInput[transition]![place]!.remove(at: newInput[transition]![place]!.firstIndex(where: {$0 == label})!)
          }
        }
      }
    }
    
    return (
      HeroNet(input: newInput, output: output, guards: guards, interpreter: interpreter),
      newMarking
    )
    
  }
  
  
  private func optimizedGuardWithSameLabel(transition: TransitionType, placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]])
  -> (HeroNet, [PlaceType: [Label: Multiset<Value>]])
  {
    guard let _ = guards[transition] else {
      return (self, placeToLabelToValues)
    }
    
    let labelSet = createLabelSet(net: self, transition: transition)
    let (conditionWithSameLabel, conditionRest) = isolateCondWithSameLabel(labelSet: labelSet, transition: transition)
    let newPlaceToLabelToValue = optimizedCondWithSameLabel(placeToLabelToValue: placeToLabelToValues, conditionsWithSameLabel: conditionWithSameLabel)
    
    var newGuard = guards
    newGuard[transition]! = conditionRest
    
    return (
      HeroNet(input: self.input, output: self.output, guards: newGuard, interpreter: interpreter),
      newPlaceToLabelToValue
    )
  }
  
  private func optimizedCondWithSameLabel(placeToLabelToValue: [PlaceType: [Label: Multiset<Value>]], conditionsWithSameLabel: [Label: [Pair<Value, Value>]]) -> [PlaceType: [Label: Multiset<Value>]]
  {

    var newPlaceToLabelToValue = placeToLabelToValue

    for (place, labelToValues) in newPlaceToLabelToValue {
      for (label, values) in labelToValues {
        if let conditions = conditionsWithSameLabel[label] {
          for condition in conditions {
            for value in Set(values) {
              if !checkGuards(condition: condition, with: [label: value]) {
                newPlaceToLabelToValue[place]![label]!.removeAll(value)
              }
            }
          }
        }
      }
    }
    
    return newPlaceToLabelToValue
    
  }
  
  /// Compute possible values for labels of each place
  /// - Parameters:
  ///   - transition: The current transition
  ///   - marking: The current marking
  /// - Returns:
  ///   Returns a dictionnary that binds each  place to its labels and their possible values
  private func computeValuesForLabel(transition: TransitionType, marking: Marking<PlaceType>)
  -> [PlaceType: [Label: Multiset<Value>]]
  {
    var placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]] = [:]
    
    if let pre = input[transition] {
      for (place, labels) in pre {
        placeToLabelToValues[place] = [:]
        for label in labels {
          placeToLabelToValues[place]![label] = marking[place]
        }
      }
    }
    
    return placeToLabelToValues
  }
  
  
  /// Isolate conditions with the same variable to apply
  /// - Parameters:
  ///   - labelSet: A set containing each label of the net
  ///   - transition: The current transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  private func isolateCondWithSameLabel(labelSet: Set<Label>, transition: TransitionType) -> ([Label: [Pair<Value, Value>]], [Pair<Value, Value>]) {

    var labelSetTemp: Set<Label> = []
    var condWithUniqueVariable: [Label: [Pair<Value, Value>]] = [:]
    var restConditions: [Pair<Value, Value>] = []

    if let conditions = guards[transition] {
      for condition in conditions {
        for label in labelSet {
          if condition.l.contains(label) || condition.r.contains(label) {
            labelSetTemp.insert(label)
          }
        }
        // Check that we have the same variable, and one of both side contains just this variable
        if labelSetTemp.count == 1 {
          if let _ = condWithUniqueVariable[labelSetTemp.first!] {
            condWithUniqueVariable[labelSetTemp.first!]!.append(condition)
          } else {
            condWithUniqueVariable[labelSetTemp.first!] = [condition]
          }
        } else {
          restConditions.append(condition)
        }
        labelSetTemp = []
      }
    }
    return (condWithUniqueVariable, restConditions)

  }
  
  
  // --------------------------------------------------------------------------------- //
  // ------------------- End of functions for dynamic optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ----------------------------- Functions for MFDD -------------------------------- //
  // --------------------------------------------------------------------------------- //
  
  private func fireableBindings(for transition: TransitionType, placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]], factory: HeroMFDDFactory) -> HeroMFDD {
    
    let labelSet = createLabelSet(net: self, transition: transition)
    
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: guards[transition]
    )
    
    // Return the precedent placeToLabelToValues value to the same one where label are now key
    let placeToKeyToValues = fromLabelToKey(labelSet: labelSet, labelWeights: labelWeights, placeToLabelToValues: placeToLabelToValues)

    let (dependentPlaceToKeyToValues, independentKeyToValues) = computeDependentAndIndependentKeys(placeToKeyToValues: placeToKeyToValues, transition: transition)
    
    var mfddPointer = constructMFDD(placeToKeyToValues: dependentPlaceToKeyToValues, transition:transition, factory: factory)
    
    // If there are conditions, we have to apply them on the MFDD
    if let conditions = guards[transition] {
      var keySet: Set<KeyMFDDLabel> = []
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
  
  /// Transform labels into key in the place to label to values structure.
  /// - Parameters:
  ///   - labelSet: A set containing each label of the net
  ///   - labelWeights: Label weights
  ///   - placeToLabelToValues: The structure to change to pass from label to key
  /// - Returns:
  ///   Returnsa dictionnary that binds each place to its key with their corresponding values
  private func fromLabelToKey (
    labelSet: Set<Label>,
    labelWeights: [Label: Int]?,
    placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]]
  ) -> [PlaceType: [KeyMFDDLabel: Multiset<Value>]] {

    let totalOrder: [Pair<Label, Label>]
    var placeToKeyToValues: [PlaceType: [KeyMFDDLabel: Multiset<Value>]] = [:]
    
    if let lw = labelWeights {
      totalOrder = createTotalOrder(labels: labelSet.sorted(by: {(label1, label2) -> Bool in
        lw[label1]! > lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(labels: Array(labelSet))
    }
    
    for (place, labelToValues) in placeToLabelToValues {
      placeToKeyToValues[place] = [:]
      for (label, values) in labelToValues {
        let key = KeyMFDDLabel(label: label, couple: totalOrder)
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
    placeToKeyToValues: [PlaceType: [KeyMFDDLabel: Multiset<Value>]],
    transition: TransitionType)
  -> ([PlaceType: [KeyMFDDLabel: Multiset<Value>]], [KeyMFDDLabel: Multiset<Value>]) {

    var independentKeysToValues: [KeyMFDDLabel: Multiset<Value>] = [:]
    var placeToDependentKeysToValues: [PlaceType: [KeyMFDDLabel: Multiset<Value>]] = [:]
    var setKeys: Set<KeyMFDDLabel> = []
    var dependentKeys: Set<KeyMFDDLabel> = []
    
    // Construct set of keys
    for (_, keyToValues) in placeToKeyToValues {
      for (key, _) in keyToValues {
        setKeys.insert(key)
      }
    }
    
    if let conditions = guards[transition] {
      for condition in conditions {
        for key in setKeys {
          if condition.l.contains(key.label) || condition.r.contains(key.label) {
            dependentKeys.insert(key)
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
  private func addIndependentLabel(mfddPointer: HeroMFDD.Pointer, independentKeyToValues: [KeyMFDDLabel: Multiset<Value>], factory: HeroMFDDFactory) -> HeroMFDD.Pointer {
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
    keyToExprs: [KeyMFDDLabel: Multiset<Value>],
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, values) = keyToExprs.sorted(by: {$0.key < $1.key}).first {
      var take: [Value: HeroMFDD.Pointer] = [:]
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
    condition: Pair<Value, Value>,
    keySet: Set<KeyMFDDLabel>,
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    var morphisms: MFDDMorphismFactory<KeyMFDDLabel, Value> { factory.morphisms }
    let keyCond = keySet.filter({(key) in
      if condition.l.contains(key.label) || condition.r.contains(key.label) {
        return true
      }
      return false
    })
    
    let morphism = guardFilter(condition: condition, keyCond: Array(keyCond), factory: factory, heroNet: self)
    
    return morphism.apply(on: mfddPointer)
    
  }
  
  private func countKeyForAnArc(transition: TransitionType, place: PlaceType, keySet: Set<KeyMFDDLabel>) -> [KeyMFDDLabel: Int] {
   
    var labelOccurences: [Label: Int] = [:]
    var keyOccurences: [KeyMFDDLabel: Int] = [:]
    
    if let labels = input[transition]?[place] {
        for label in labels {
          if let _ = labelOccurences[label] {
            labelOccurences[label]! += 1
          } else {
            labelOccurences[label] = 1
          }
        }
    }
    
    for key in keySet {
      keyOccurences[key] = labelOccurences[key.label]
    }
    
    return keyOccurences
  }
  
  private func constructMFDD(
    placeToKeyToValues: [PlaceType: [KeyMFDDLabel: Multiset<Value>]],
    transition: TransitionType,
    factory: HeroMFDDFactory) -> HeroMFDD.Pointer
  {
    var mfddPointer = factory.zero.pointer
    var keySet: Set<KeyMFDDLabel> = []
    
    for (_, keyToValues) in placeToKeyToValues {
      for (key, _) in keyToValues {
        keySet.insert(key)
      }
    }
    
    for (place, keyToValues) in placeToKeyToValues {
      
      let keyOccurences = countKeyForAnArc(transition: transition, place: place, keySet: keySet)
      
      var keyToValuesWithKeyOccurence: [KeyMFDDLabel: (Multiset<Value>, Int)] = [:]
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
  ///   - keyToValuesAndOccurences: A dictionnary that binds a key to its possible expressions
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args for a place.
  private func constructMFDD(
    keyToValuesAndOccurences: [KeyMFDDLabel: (Multiset<Value>, Int)],
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToValuesAndOccurences.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, (values, n)) = keyToValuesAndOccurences.sorted(by: {$0.key < $1.key}).first {
      var take: [Value: HeroMFDD.Pointer] = [:]
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
    labelSet: Set<Label>,
    conditions: [Pair<Value, Value>]?)
  -> ([Label: Int]?, [Pair<Value, Value>: Int]?) {
    
    // If there is no conditions
    guard let _ = conditions else {
      return (nil, nil)
    }
    var labelWeights: [Label: Int] = [:]
    var conditionWeights: [Pair<Value, Value>: Int] = [:]
    var labelForCond: [Set<Label>] = []
    var labelInACond: Set<Label> = []
    
    // Initialize the score to 100 for each variable
    // To avoid that a same variable has the same score, we increment its n value, allowing to distingue them
    for label in labelSet {
      labelWeights[label] = 100
    }
    
    for condition in conditions! {
      conditionWeights[condition] = 100
    }
    
    // To know condition variables
    for condition in conditions! {
      for label in labelSet {
        if condition.l.contains(label) || condition.r.contains(label) {
          labelInACond.insert(label)
        }
      }
      
      // Compute condition weights
      if labelInACond.count != 0 {
        conditionWeights[condition]! *= 2/labelInACond.count
      } else {
        conditionWeights[condition]! = 0
      }
      
      labelForCond.append(labelInACond)
      labelInACond = []
    }
    
    // To compute a score
    // If a condition contains the same variable, it earns 50 points
    // If a condition contains a variable with other variables, every variables earn 10 points
    for (label, _) in labelWeights {
      for cond in labelForCond {
        if cond.contains(label) {
          if cond.count == 1  {
            labelWeights[label]! += 100
          } else {
            labelWeights[label]! += 10
          }
        }
      }
    }
    
    return (labelWeights, conditionWeights)
  }
  
  // createOrder creates a list of pair from a list of string
  // to represent a total order relation. Pair(l,r) => l < r
  func createTotalOrder(labels: [Label]) -> [Pair<Label, Label>] {
      var r: [Pair<Label, Label>] = []
      for i in 0 ..< labels.count {
        for j in i+1 ..< labels.count {
          r.append(Pair(labels[i],labels[j]))
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
  
  private func createLabelSet(net: HeroNet, transition: TransitionType) -> Set<Label> {
    var labelSet: Set<Label> = []
    
    // Construct labelList by looking at on arcs
    if let pre = net.input[transition] {
      for (_, labels) in pre {
        for label in labels {
          labelSet.insert(label)
        }
      }
    }
    return labelSet
  }
  
}


