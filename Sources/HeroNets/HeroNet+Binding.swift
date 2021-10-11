import DDKit
import Interpreter

/// A Hero net binding computes all the possibles marking for a given  transition
extension HeroNet {
    
  public typealias KeyMFDD = Key<Label>
  public typealias HeroMFDD = MFDD<KeyMFDD,Value>
  public typealias HeroMFDDFactory = MFDDFactory<KeyMFDD,Value>
    
  
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
  
  func fireableBindings(for transition: TransitionType, placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]], factory: HeroMFDDFactory) -> HeroMFDD {
    
    let labelSet = createLabelSet(net: self, transition: transition)
    
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: guards[transition]
    )
    
    // Return the sorted key to expressions list
//    let keyToExprs = computeKeyToExprs(
//      labelSet: labelSet,
//      labelWeights: labelWeights,
//      labelToExprs: labelToExprs
//    )
//    
//    let (independantKeysToExprs, dependantKeysToExprs) = computeIndependantAndDependantKeys(
//      keyToExprs: keyToExprs,
//      conditions: condRest,
//      transition: transition
//    )
    
    return factory.zero
  }
  
  
  /// Creates the fireable bindings of a transition.
  ///
  /// - Parameters:
  ///   - transition: The transition for which we want to compute all bindings
  ///   - marking: The marking which is the initial state of the net
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   The MFDD which represents all fireable bindings.
  private func computeBindings(for transition: TransitionType, with marking: Marking<PlaceType>, factory: HeroMFDDFactory) -> HeroMFDD {
    
    
    // --------------------------------------------------------------------------------- //
    // --------------- Compute first MFDD (Apply homomorphism on places) --------------- //
    // --------------------------------------------------------------------------------- //
    
    // All variables imply in the transition firing keeping the group by arc
    var labelSet: Set<Label> = []
    
    // placeToExprs: Expressions contain in a place
    // placeToLabels: Labels related to a place
    var placeToExprs: [PlaceType: Multiset<Value>] = [:]
    var placeToLabels: [PlaceType: Multiset<Label>] = [:]
    
    var varMultiset: Multiset<Label> = []
    // Preprocess the net, removing constant on the arc and consuming the value in the corresponding place
    // and creates the list of variables
    if let pre = input[transition] {
      for (place, labels) in pre {
        placeToExprs[place] = marking[place]
        for lab in labels {
          if !lab.contains("$") {
            if placeToExprs[place]!.contains(lab) {
              // Remove one occurence
              placeToExprs[place]!.remove(lab)
            } else {
              return factory.zero
            }
          } else {
            varMultiset.insert(lab)
            labelSet.insert(lab)
          }
        }
        placeToLabels[place] = varMultiset
        varMultiset = []
      }
    }
    
    // Get all the possibilities for each labels
    var labelToExprs = associateLabelToExprsForPlace(placeToExprs: placeToExprs, transition: transition)
    
    // Isolate condition with a unique variable
    let (condWithUniqueLab, condRest) = isolateCondWithSameLabel(labelSet: labelSet, transition: transition)
      

    // Check for condition with a unique label and simplify the range of possibility for the corresponding label
    // E.g.: Suppose the guard: (x,1), x can be only 1.
    labelToExprs = optimizationSameVariable(labelToExprs: labelToExprs, conditionsWithUniqueLabel: condWithUniqueLab)
        
    // Compute a score for label and conditions. It takes only conditions that are relevant, i.e. conditions which are not with a single label or an equality between two label.
    let (labelWeights, conditionWeights) = computeScoreOrder(
      labelSet: labelSet,
      conditions: condRest
    )
        
    // Return the sorted key to expressions list
    let keyToExprs = computeKeyToExprs(
      labelSet: labelSet,
      labelWeights: labelWeights,
      labelToExprs: labelToExprs
    )
    
    let (independantKeysToExprs, dependantKeysToExprs) = computeIndependantAndDependantKeys(
      keyToExprs: keyToExprs,
      conditions: condRest,
      transition: transition
    )
    
    if let pre = input[transition] {
      let arcLabelsDependantKeys = Dictionary(uniqueKeysWithValues: pre.map({(el) in
        return (el.key,
          el.value.filter({(label) in
            dependantKeysToExprs.contains(where: {$0.key.label == label})
          })
        )
      }))
      
      // Construct the mfdd
      var mfddPointer = constructMFDD(
        keyToExprs: dependantKeysToExprs,
        arcLabels: arcLabelsDependantKeys,
        factory: factory,
        placeToExprs: placeToExprs,
        placeToLabels: placeToLabels
      )
      
      
      if condRest != []  {
        var keySet: Set<KeyMFDD> = []

        for (key, _) in keyToExprs {
          keySet.insert(key)
        }
          
        for condition in condRest.sorted(by: {conditionWeights![$0]! > conditionWeights![$1]!}) {
          // Apply guards
          mfddPointer = applyCondition(
            mfddPointer: mfddPointer,
            condition: condition,
            keySet: keySet,
            factory: factory
          )
        }
      }
      
      // Add independant labels at the end of the process, to reduce the combinatory explosion. These labels does not impact the result !
      mfddPointer = addIndependantVariable(mfddPointer: mfddPointer, independantKeyToExprs: independantKeysToExprs, factory: factory)
      
      return MFDD(pointer: mfddPointer, factory: factory)
    }
    return factory.one

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
  func computeStaticOptimizedNet(transition: TransitionType) -> HeroNet? {
    let netEqualityInGuardOptimization = optimizeEqualityInGuard(transition: transition)
    let netConstantPropagationOptimization = optimizationConstantPropagation(net: netEqualityInGuardOptimization, transition: transition)
    return netConstantPropagationOptimization
  }
  
  /// The constant propagation optimization uses guard of the form "x = constant expression" to replace all occurences of x by the constant expression in every possible expressions (e.g.: arcs, guards)
  /// - Parameters:
  ///   - net:The net that is optimized
  ///   - transition: The current transition
  /// - Returns:
  ///  Returns a new net where constant propagation is applied
  func optimizationConstantPropagation(net: HeroNet, transition: TransitionType) -> HeroNet? {
    
    let labelSet = createLabelSet(net: net, transition: transition)
    
    if let conditions = net.guards[transition] {
      // Isolate condition with a unique variable
      let (dicSameLabelToCondition, condRest) = isolateCondWithUniqueLabel(labelSet: labelSet, conditions: conditions)
      
      if let labelToConstant = createDicOfConstantLabel(dicUniqueLabelToCondition: dicSameLabelToCondition) {
        // We do not keep condition with a unique label in the future net !
        var guardsTemp = net.guards
        guardsTemp[transition] = condRest
        let netTemp = HeroNet(input: net.input, output: net.output, guards: guardsTemp, module: net.module)
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
  func replaceLabelsForATransition(labelToValue: [Label: Value], transition: TransitionType, net: HeroNet) -> HeroNet {
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
        
    return HeroNet(input: newInput, output: newOutput, guards: newGuards, module: self.module)
  }
  
  /// Takes a dictionnary of label binds to condition with a unique variable, then evaluates each condition to have a value for each expression.
  /// Each label is associated to a value.
  /// - Parameters:
  ///   - dicUniqueLabelToCondition: The dictionnary that binds label to a list of conditions which are already in the good format (i.e.: var == a constant expression)
  /// - Returns:
  ///  Returns a new dictionnary of label to values, where each previous expressions has been evaluated
  func createDicOfConstantLabel(dicUniqueLabelToCondition: [Label: [Pair<Value>]]) -> [Label: Value]? {
    
    // Need to create the interpreter here for performance
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    var constantCondition: [Label: Value] = [:]
    
    for (label, conditionList) in dicUniqueLabelToCondition {
      for condition in conditionList {
        var value: Value = ""
        if condition.l == label {
          value = try! "\(interpreter.eval(string: condition.r))"
          if value.contains("func") {
            value = condition.r
          }
        } else {
          value = try! "\(interpreter.eval(string: condition.l))"
          if value.contains("func") {
            value = condition.l
          }
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
  func optimizeEqualityInGuard(transition: TransitionType) -> HeroNet {
    // Equality guards
    let equivalentVariables  = createDicOfEquivalentLabel(transition: transition)
    
    return replaceLabelsForATransition(labelToValue: equivalentVariables, transition: transition, net: self)
  }
  
  /// Creates a dictionnary from the equivalent label that binds a label to its new name. It means that if we have a condition of the form " x = y", a new entry will be added in the dictionnary (e.g.: [x:y]). At the end this dictionnary will  be used to know which labels has to be replaced.
  /// - Parameters:
  ///   - transition: The transition that is looking at
  /// - Returns:
  ///  Returns a dictionnary of label to label where the key is the old name of the label and the value its new name
  func createDicOfEquivalentLabel(transition: TransitionType) -> [Label: Label] {
    
    guard let _ = guards[transition] else { return [:] }
    
    let labelSet = createLabelSet(net: self, transition: transition)
    
    var eqLabelList: [Pair<Label>] = []
    
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
  
  // --------------------------------------------------------------------------------- //
  // -------------------- End of functions for static optimization ------------------- //
  // --------------------------------------------------------------------------------- //
  
  // --------------------------------------------------------------------------------- //
  // ---------------------- Functions for dynamic optimization ----------------------  //
  // --------------------------------------------------------------------------------- //
  
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
      let (optimizedNetWithSameVariable, placeToLabelToValuesWithSameVariable) = optimizedGuardWithSameLabel(transition: transition, placeToLabelToValues: placeToLabelToValues)
      // If the same label appears on different arcs, it's kept only values that are valid for both places.
      // However, it does not modify the number of values that belong to the label.
      let placeToLabelToValuesWithSameLabelOnArcs = optimizedSameLabelOnArcs(placeToLabelToValues: placeToLabelToValuesWithSameVariable)
      
      return (optimizedNetWithSameVariable, placeToLabelToValuesWithSameLabelOnArcs)
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
      HeroNet(input: newInput, output: output, guards: guards, module: module),
      newMarking
    )
    
  }
  
  private func optimizedSameLabelOnArcs(placeToLabelToValues: [PlaceType: [Label: Multiset<Value>]]) -> [PlaceType: [Label: Multiset<Value>]] {
    
    var uniqueValuesForLabel: [Label: Multiset<Value>] = [:]
    
    // Just keep unique values for each label
    for (_, labelToValues) in placeToLabelToValues {
      for (label, values) in labelToValues {
        if let _ = uniqueValuesForLabel[label] {
          uniqueValuesForLabel[label]! = uniqueValuesForLabel[label]!.intersection(values)
        } else {
          uniqueValuesForLabel[label] = values
        }
      }
    }
    
    var newPlaceToLabelToValues = placeToLabelToValues
    // Looking at labels and applying intersection upperbound to keep only values that appeared in uniqueValuesForLabel with their maximum value
    for (place, labelToValues) in newPlaceToLabelToValues {
      for (label, values) in labelToValues {
        if !(values == uniqueValuesForLabel[label]!) {
          newPlaceToLabelToValues[place]![label]! = newPlaceToLabelToValues[place]![label]!.intersectionUpperBound(uniqueValuesForLabel[label]!)
        }
      }
    }
    
    return newPlaceToLabelToValues
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
      HeroNet(input: self.input, output: self.output, guards: newGuard, module: self.module),
      newPlaceToLabelToValue
    )
  }
  
  func optimizedCondWithSameLabel(placeToLabelToValue: [PlaceType: [Label: Multiset<Value>]], conditionsWithSameLabel: [Label: [Pair<Value>]]) -> [PlaceType: [Label: Multiset<Value>]]
  {

    var newPlaceToLabelToValue = placeToLabelToValue
    
    // Need to create the interpreter here for performance
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    for (place, labelToValues) in newPlaceToLabelToValue {
      for (label, values) in labelToValues {
        if let conditions = conditionsWithSameLabel[label] {
          for condition in conditions {
            for value in Set(values) {
              if !checkGuards(condition: condition, with: [label: value], interpreter: interpreter) {
                newPlaceToLabelToValue[place]![label]!.removeAll(value)
              }
            }
          }
        }
      }
    }
    
    return newPlaceToLabelToValue
    
  }
  
  private func computeValuesForLabel(transition: TransitionType, marking:Marking<PlaceType>)
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
  ///   - LabelSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  private func isolateCondWithSameLabel(labelSet: Set<Label>, transition: TransitionType) -> ([Label: [Pair<Value>]], [Pair<Value>]) {

    var labelSetTemp: Set<Label> = []
    var condWithUniqueVariable: [Label: [Pair<Value>]] = [:]
    var restConditions: [Pair<Value>] = []

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
  

  
  
  /// Find and remove guards of the form: ($x, constant). It filters values that have the same label to keep only values that are true applying the condition.
  /// It is an optimisation to reduce the number of conditions and the number of possible values that will be generated at the begining.
  /// - Parameters:
  ///   - labelToExprs: Label with their corresponding expressions
  ///   - conditionsWithUniqueLabel: Conditions with a unique label inside (e.g.: ($x, 1)), wrong example: ($y,$x+1))
  /// - Returns:
  ///   Returns the possible multiset values for each label
  func optimizationSameVariable(labelToExprs: [Label: Multiset<Value>], conditionsWithUniqueLabel: [Label: [Pair<Value>]]) -> [Label: Multiset<Value>] {
    
    var labelToExprsTemp = labelToExprs
    
    // Need to create the interpreter here for performance
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)

    // We manage the case with conditions that contain a unique label
    for (labCond, condRest) in conditionsWithUniqueLabel {
      for expr in labelToExprs[labCond]! {
        for cond in condRest {
          if !checkGuards(condition: cond, with: [labCond: expr], interpreter: interpreter) {
            labelToExprsTemp[labCond]!.removeAll(expr)
          }
        }
      }
    }
    
    return labelToExprsTemp
  }
  
  
  func createLabelSet(net: HeroNet, transition: TransitionType) -> Set<Label> {
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
  
  /// Remove constants on arcs and filter the values inside the place. A constant as a label can be just removed if we remove a value in the corresponding place.
  /// - Parameters:
  ///   - placeToExprs: Each place is bound to a multiset of expressions
  ///   - arcLabels: Each label for each arc
  /// - Returns:
  ///   Returns a tuple where the first element is a dictionnary that binds place with its possible expressions (removing constant), and the second element is the new list of label for each place,  where constants are removed from it
  func removeConstant(
    placeToExprs: [PlaceType: Multiset<Value>],
    transition: TransitionType
  ) -> ([PlaceType: Multiset<Value>], [PlaceType: [Label]]) {
    var placeToExprsConstantFiltered = placeToExprs
    
    if let pre = input[transition] {
      var arcLabelsWithoutConstant = pre
      for (place, labels) in pre {
        for label in labels {
          if !label.contains("$") {
            placeToExprsConstantFiltered[place]!.remove(label)
            arcLabelsWithoutConstant[place]!.removeAll(where: {$0 == label})
          }
        }
      }
      return (placeToExprsConstantFiltered, arcLabelsWithoutConstant)
    }
    
    return (placeToExprsConstantFiltered, [:])
  }
  
  /// Separate the dictionnary of key to expressions in two distinct dictionnaries where one contains independant keys (resp. dependant keys) bind to their expressions.
  /// - Parameters:
  ///   - keyToExprs: Each key is bound to a multiset of expressions
  ///   - conditions: List of conditions
  ///   - arcLabels: Each label for each arc
  /// - Returns:
  ///   Returns a tuple of two dictionnary, where the first one is for independant keys and the second one for dependant keys.
  func computeIndependantAndDependantKeys(
    keyToExprs: [KeyMFDD: Multiset<Value>],
    conditions: [Pair<Value>],
    transition: TransitionType)
  -> (independantKeys: [KeyMFDD: Multiset<Value>], dependantKeys: [KeyMFDD: Multiset<Value>]) {
    
    var independantKeys: [KeyMFDD: Multiset<Value>] = [:]
    var dependantKeys: [KeyMFDD: Multiset<Value>] = [:]
    var independant: Bool = true
    
    if let pre = input[transition] {
      for (key, exprs) in keyToExprs {
        for (_, labels) in pre {
          if labels.count >= 2 && labels.contains(key.label) {
            independant = false
            break
          }
        }
        
        if independant != false {
          for condition in conditions {
            if condition.l.contains(key.label) || condition.r.contains(key.label) {
              independant = false
              break
            }
          }
        }
        
        if independant == true {
          independantKeys[key] = exprs
        } else {
          dependantKeys[key] = exprs
        }
        
        independant = true
      }
    }
    
    return (independantKeys: independantKeys, dependantKeys: dependantKeys)
  }
  
  /// Takes the current MFDD and adds values for independant keys. It allows to construct the first mfdd with conditions only on variables that can be affected by it, then just adding like a simple concatenation for the rest of values.
  /// Do not need to evaluate anything !
  /// - Parameters:
  ///   - mfddPointer:Current mfdd pointer
  ///   - independantKeyToExprs: List of keys with their expressions with no influenced between keys in the net.
  ///   - factory: Current factory
  /// - Returns:
  ///   Returns a new mfdd pointer where values of the independant keys have been added.
  func addIndependantVariable(mfddPointer: HeroMFDD.Pointer, independantKeyToExprs: [KeyMFDD: Multiset<Value>], factory: HeroMFDDFactory) -> HeroMFDD.Pointer {
    let mfddPointerForIndependantKeys = constructMFDDIndependantKeys(keyToExprs: independantKeyToExprs, factory: factory)
    return factory.concatAndFilterInclude(mfddPointer, mfddPointerForIndependantKeys)
  }
  
  /// Construct the MFDD for independant keys, without the need to filter.
  /// - Parameters:
  ///   - keyToExprs: Each key is bound to a multiset of expressions
  ///   - factory: Current factory
  /// - Returns:
  ///   Returns the MFDD that represents all independant keys with their corresponding values
  func constructMFDDIndependantKeys(
    keyToExprs: [KeyMFDD: Multiset<Value>],
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
        take[el] = constructMFDDIndependantKeys(
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
  func applyCondition(
    mfddPointer: HeroMFDD.Pointer,
    condition: Pair<Value>,
    keySet: Set<KeyMFDD>,
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    var morphisms: MFDDMorphismFactory<KeyMFDD, Value> { factory.morphisms }
    let keyCond = keySet.filter({(key) in
      if condition.l.contains(key.label) || condition.r.contains(key.label) {
        return true
      }
      return false
    })
        
    var interpreter = Interpreter()
    try! interpreter.loadModule(fromString: module)
    
    let morphism = guardFilter(condition: condition, keyCond: Array(keyCond), factory: factory, heroNet: self, interpreter: interpreter)
    
    return morphism.apply(on: mfddPointer)
    
  }
  

  /// Isolate conditions with the same variable to apply
  /// - Parameters:
  ///   - LabelSet: An array containing a list of keys binds to their possible expressions
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a dictionnary that binds label to their conditions where the label is the only to appear
  func isolateCondWithUniqueLabel(labelSet: Set<Label>, conditions: [Pair<Value>]?) -> ([Label: [Pair<Value>]], [Pair<Value>]) {

    var condWithUniqueVariable: [Label: [Pair<Value>]] = [:]
    var restConditions: [Pair<Value>] = []

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
  
  
  
  /// Creates a MFDD pointer that represents all possibilities for a transition without guards.
  /// A MFDD pointer is computed for each place before being merge with a specific homomorphism.
  ///
  /// - Parameters:
  ///   - keyToExprs: A dictionnary that binds a key to its possible expressions
  ///   - arcLabelsWithoutConstant: Labels of the current arc
  ///   - factory: The factory to construct the MFDD
  ///   - placeToExprs: The list of expressions for each place
  ///   - placeToLabels: The list of labels for each place
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args.
  func constructMFDD(
    keyToExprs: [KeyMFDD: Multiset<Value>],
    arcLabels: [PlaceType: [Label]],
    factory: HeroMFDDFactory,
    placeToExprs: [PlaceType: Multiset<Value>],
    placeToLabels: [PlaceType: Multiset<Label>]
  ) -> HeroMFDD.Pointer {

    var keyToExprsForAPlace: [KeyMFDD: (Multiset<Value>, Int)] =  [:]
    var labelToKey: [Label: KeyMFDD] = [:]
    
    for (key, _) in keyToExprs {
      labelToKey[key.label] = key
    }
              
    var mfddPointer = factory.zero.pointer
    
    for (place, labels) in arcLabels {
      keyToExprsForAPlace = computeExprsForALabelOfAPlace(
        place: place,
        labels: labels,
        labelToKey: labelToKey,
        keyToExprs: keyToExprs,
        placeToExprs: placeToExprs)

      let mfddTemp = constructMFDD(keyToExprs: keyToExprsForAPlace, factory: factory)
      
      // Apply the homomorphism
      mfddPointer = factory.concatAndFilterInclude(mfddPointer, mfddTemp)
      keyToExprsForAPlace = [:]
    }

    return mfddPointer
    
  }
  
  
  /// Creates a MFDD pointer that represents all possibilities for a place without guards
  /// The MFDD is specific for a place.
  ///
  /// - Parameters:
  ///   - keyToExprs: A dictionnary that binds a key to its possible expressions, where keyToExprs contains only key for the given pre arc of a transition
  ///   - factory: The factory to construct the MFDD
  /// - Returns:
  ///   A MFDD pointer that contains every possibilities for the given args for a place.
  func constructMFDD(
    keyToExprs: [KeyMFDD: (Multiset<Value>, Int)],
    factory: HeroMFDDFactory
  ) -> HeroMFDD.Pointer {
    
    if keyToExprs.count == 0 {
      return factory.one.pointer
    }
    
    if let (key, (values, n)) = keyToExprs.sorted(by: {$0.key < $1.key}).first {
      var take: [Value: HeroMFDD.Pointer] = [:]
      var keyToExprsFirstDrop = keyToExprs
      keyToExprsFirstDrop.removeValue(forKey: key)
      
      for el in values {
        // Check we have enough element in values
        if values.occurences(of: el) >= n {
          take[el] = constructMFDD(
            keyToExprs: keyToExprsFirstDrop.reduce(into: [:], {(res, couple) in
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
  
  
  /// Creates a dictionnary of key to multiset of expressions for a specific place
  /// Therefore, we get each possible values for a key.
  /// In addition, there is another trick here. Earlier in the process, we do an intersection to keep only possible values for a same variable.
  /// It could be a problem when there is no the same amount of a same value in two places (either it is more or less).
  /// Let suppose: P1 -(x,y)-> T1, P2 -(x)-> T1, with P1: {"1", "1", "2"}, P2: {"1"}
  /// When we do the first intersection at the beginning of the process, we get "x": {"1"}, even though "x" appears two times in P1
  /// If we try to create the MFDD with this information, we can have a scenario where "y" is at the top of the MFDD and takes "1".
  /// So, "x" cannot select "1" again if we do not know there is two "1" in P1.
  /// The same logic is applicable in the other way, if we try to take the upperbound directly, cause we could suppose that a place has more a value than it is supposed to be.
  /// Therefore, the intersection upperbound is called only at the time we want to have the correct number of values for a place and a label.
  /// - Parameters:
  ///   - place: The current place
  ///   - labels: List of labels of the place,
  ///   - labelToKey: Associates each label to its own key
  ///   - keyToExprs. Associates each key to its possible expressions
  ///   - placeToExprs: Original values available in a place
  /// - Returns:
  ///   The real number of expressions for each label of a place
  func computeExprsForALabelOfAPlace(
    place: PlaceType,
    labels: [Label],
    labelToKey: [Label: KeyMFDD],
    keyToExprs: [KeyMFDD: Multiset<Value>],
    placeToExprs: [PlaceType: Multiset<Value>])
  -> [KeyMFDD: (Multiset<Value>, Int)] {
    
    var keyToExprsForAPlace: [KeyMFDD: (Multiset<Value>, Int)] =  [:]

    for label in labels {
      let key = labelToKey[label]!
      if let _ = keyToExprsForAPlace[key] {
        keyToExprsForAPlace[key]!.1 += 1
      } else {
        keyToExprsForAPlace[key] = (
          keyToExprs[labelToKey[label]!]!.intersectionUpperBound(placeToExprs[place]!),
          1
        )
      }
    }
    return keyToExprsForAPlace
  }

  
  /// Create a label for each variable and associates the possible expressions. If the same variable appears multiple times, an intersection is made between multisets to keep only possible values. e.g.: ["1": 2, "2": 1, "4": 1] ∩ ["1": 1, "2": 1, "3": 1] = ["1": 1, "2": 1].
  /// Hence, if two places have different values, a variable that appears in precondition arcs of both can only take a value in the intersection.
  ///
  /// - Parameters:
  ///   - placeToExprs: Marking of each place (that has been modified earlier)
  ///   - transition: The transition for which we want to compute all bindings
  /// - Returns:
  ///   A dictionnary that associates each label to their expressions
  func associateLabelToExprsForPlace(
    placeToExprs: [PlaceType: Multiset<Value>],
    transition:  TransitionType) -> [Label: Multiset<Value>]
  {
    var labelToExprs: [Label: Multiset<Value>] = [:]
    if let pre = input[transition] {
      for (place, labels) in pre {
        for label in labels {
          if let _ = labelToExprs[label] {
            labelToExprs[label] = labelToExprs[label]!.intersection(placeToExprs[place]!)
          } else {
            labelToExprs[label] = placeToExprs[place]!
          }
        }
      }
      return labelToExprs
    }
    return [:]
  }
  
  /// Compute a score for each variable using the guards, and the score of priority for each conditions. The score is used to determine the order to apply conditions
  ///
  /// - Parameters:
  ///   - labelSet: Set of labels
  ///   - conditions: List of condition for a specific transition
  /// - Returns:
  ///   Return a tuple with its first element a dictionnary that binds a label to its weight and second element a dictionnary that binds condition to a score !
  func computeScoreOrder(
    labelSet: Set<Label>,
    conditions: [Pair<Value>]?)
  -> ([Label: Int]?, [Pair<Value>: Int]?) {
    
    // If there is no conditions
    guard let _ = conditions else {
      return (nil, nil)
    }
    var labelWeights: [Label: Int] = [:]
    var conditionWeights: [Pair<Value>: Int] = [:]
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
 
  /// Return the array of all possibles values for each labels that are transformed into keys. MFDD requires to have a total order relation between variables, so we construct this order using the weight computed before. We transform the precedent array of labels with expressions into an array of keys related to their multiset of expressions. This result is ordered using label weights.
  ///
  /// - Parameters:
  ///   - labelSet: The set of labels
  ///   - labelWeights: The weight of labels
  ///   - labelToExprs: A dictionnary of label binds to their possible expressions
  /// - Returns:
  ///   A sorted array that binds each key to their expressions, grouped by places and sorted using label weights
  func computeKeyToExprs(
    labelSet: Set<Label>,
    labelWeights: [Label: Int]?,
    labelToExprs: [Label: Multiset<Value>]
  ) -> [KeyMFDD: Multiset<Value>] {

    let totalOrder: [Pair<Label>]
    var keyToExprs: [KeyMFDD: Multiset<Value>] = [:]
    
    if let lw = labelWeights {
      totalOrder = createTotalOrder(labels: labelSet.sorted(by: {(label1, label2) -> Bool in
        lw[label1]! > lw[label2]!
      }))
    } else {
      totalOrder = createTotalOrder(labels: Array(labelSet))
    }
    
    for (label,exprs) in labelToExprs {
      keyToExprs[KeyMFDD(label: label, couple: totalOrder)] = exprs
    }

    return keyToExprs
  }

  // createOrder creates a list of pair from a list of string
  // to represent a total order relation. Pair(l,r) => l < r
  func createTotalOrder(labels: [Label]) -> [Pair<Label>] {
      var r: [Pair<Label>] = []
      for i in 0 ..< labels.count {
        for j in i+1 ..< labels.count {
          r.append(Pair(labels[i],labels[j]))
        }
      }
      return r
  }
  
}
