extension HeroNet: CustomStringConvertible {
  public var description: String {
    var res: String = ""
    
    for transition in TransitionType.allCases {
      res.append("Transition: \(transition) \n")
      res.append("Input arcs:\n")
      
      if let inputs = input[transition] {
        for (place, labels) in inputs {
          res.append("Place: \(place)\n")
          res.append("Labels: \(labels)\n")
        }
      } else {
        res.append("No input arc\n")
      }
      
      res.append("Output arcs:\n")
      if let outputs = output[transition] {
        for (place, labels) in outputs {
          res.append("Place: \(place)\n")
          res.append("Labels: \(labels)\n")
        }
      } else {
        res.append("No output arc\n")
      }
      
      res.append("Transition guards:\n")
      if let conditions = guards[transition] {
        for condition in conditions {
          res.append("\(condition.l) == \(condition.r)\n")
        }
      } else {
        res.append("No guards\n")
      }
      
    }
    
    return res
  }
}
