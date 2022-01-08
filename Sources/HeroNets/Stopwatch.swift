import Dispatch

// A simple structure to compute the time that takes the execution of a process.
public struct Stopwatch {
  // Lifecycle

  public init() {
    startTime = DispatchTime.now()
  }

  // Public

  public struct TimeInterval: Comparable {
    // Lifecycle

    public init(ns: UInt64) {
      self.ns = ns
    }

    public init(μs: Double) {
      ns = UInt64(μs * 1000)
    }

    public init(ms: Double) {
      ns = UInt64(ms * 1_000_000)
    }

    public init(s: Double) {
      ns = UInt64(s * 1_000_000_000)
    }

    // Public

    public let ns: UInt64

    public var μs: Double {
      Double(ns) / 1000
    }

    public var ms: Double {
      Double(ns) / 1_000_000
    }

    public var s: Double {
      Double(ns) / 1_000_000_000
    }

    public var humanFormat: String {
      guard ns >= 1000 else { return "\(ns)ns" }
      guard ns >= 1_000_000 else { return "\((μs * 100).rounded() / 100)μs" }
      guard ns >= 1_000_000_000 else { return "\((ms * 100).rounded() / 100)ms" }
      guard ns >= 1_000_000_000_000 else { return "\((s * 100).rounded() / 100)s" }

      var minutes = ns / 60_000_000_000_000
      let seconds = ns % 60_000_000_000_000
      guard minutes >= 60 else { return "\(minutes)m \(seconds)s" }

      let hours = minutes / 60
      minutes = minutes % 60
      return "\(hours)h \(minutes)m \(seconds)s"
    }

    public static func< (lhs: TimeInterval, rhs: TimeInterval) -> Bool {
      lhs.ns < rhs.ns
    }
  }

  public var elapsed: TimeInterval {
    let nano = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    return TimeInterval(ns: nano)
  }

  public mutating func reset() {
    startTime = DispatchTime.now()
  }

  // Private

  private var startTime: DispatchTime
}


extension Double {
    public func truncate(places : Int)-> Double {
        return Double(floor(pow(10.0, Double(places)) * self)/pow(10.0, Double(places)))
    }
}
