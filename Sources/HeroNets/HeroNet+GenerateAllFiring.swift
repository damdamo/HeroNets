extension HeroNet {
  
  public func generateAllFiring(for transition: TransitionType, with marking: Marking<PlaceType>)
  -> Set<Marking<PlaceType>>
  {
    
    let factory = HeroMFDDFactory()
    let netStaticOptimized = computeStaticOptimizedNet(transition: transition)
    
    if let netStaticOptimized = netStaticOptimized {
      let allBindings = netStaticOptimized.fireableBindings(for: transition, with: marking, factory: factory)
      var res: Set<Marking<PlaceType>> = [marking]
      
      for binding in allBindings {
        let bindingWithLabel = Dictionary(
          uniqueKeysWithValues: binding.map {
            (key, value) in
              (key.label, value)
          })
                
        res.insert(netStaticOptimized.fire(transition: transition, from: marking, with: bindingWithLabel)!)
      }
      
      return res
    }
    
    return []
  }
}


