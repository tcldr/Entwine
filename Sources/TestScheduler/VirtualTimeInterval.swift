
import Combine

// MARK: - VirtualTimeInterval value definition

public struct VirtualTimeInterval {
    
    internal var _duration: Int
    
    init(_ duration: Int) {
        _duration = duration
    }
}

// MARK: - SignedNumeric conformance

extension VirtualTimeInterval: SignedNumeric {
    
    public typealias Magnitude = Int
    
    public var magnitude: Int { Int(_duration.magnitude) }
    
    public init?<T>(exactly source: T) where T : BinaryInteger {
        guard let value = Int(exactly: source) else { return nil }
        self.init(value)
    }
    
    public static func * (lhs: VirtualTimeInterval, rhs: VirtualTimeInterval) -> VirtualTimeInterval {
        .init(lhs._duration * rhs._duration)
    }
    
    public static func *= (lhs: inout VirtualTimeInterval, rhs: VirtualTimeInterval) {
        lhs._duration *= rhs._duration
    }
    
    public static func + (lhs: VirtualTimeInterval, rhs: VirtualTimeInterval) -> VirtualTimeInterval {
        .init(lhs._duration + rhs._duration)
    }
    
    public static func - (lhs: VirtualTimeInterval, rhs: VirtualTimeInterval) -> VirtualTimeInterval {
        .init(lhs._duration - rhs._duration)
    }
    
    public static func += (lhs: inout VirtualTimeInterval, rhs: VirtualTimeInterval) {
        lhs._duration += rhs._duration
    }
    
    public static func -= (lhs: inout VirtualTimeInterval, rhs: VirtualTimeInterval) {
        lhs._duration -= rhs._duration
    }
}

// MARK: - Comparable conformance

extension VirtualTimeInterval: Comparable {
    
    public static func < (lhs: VirtualTimeInterval, rhs: VirtualTimeInterval) -> Bool {
        lhs._duration < rhs._duration
    }
}

// MARK: - ExpressibleByIntegerLiteral conformance

extension VirtualTimeInterval: ExpressibleByIntegerLiteral {
    
    public typealias IntegerLiteralType = Int
    
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

// MARK: - SchedulerTimeIntervalConvertible conformance

extension VirtualTimeInterval: SchedulerTimeIntervalConvertible {
    
    public static func seconds(_ s: Int) -> VirtualTimeInterval {
        return .init(s)
    }
    
    public static func seconds(_ s: Double) -> VirtualTimeInterval {
        return .init(Int(s + 0.5))
    }
    
    public static func milliseconds(_ ms: Int) -> VirtualTimeInterval {
        .seconds(Double(ms) / 1e+3)
    }
    
    public static func microseconds(_ us: Int) -> VirtualTimeInterval {
        .seconds(Double(us) / 1e+6)
    }
    
    public static func nanoseconds(_ ns: Int) -> VirtualTimeInterval {
        .seconds(Double(ns) / 1e+9)
    }
}

// MARK: - VirtualTime artithmetic

extension VirtualTimeInterval {
    
    public static func * (lhs: VirtualTime, rhs: VirtualTimeInterval) -> VirtualTime {
        .init(lhs._time * rhs._duration)
    }
    
    public static func *= (lhs: inout VirtualTime, rhs: VirtualTimeInterval) {
        lhs._time *= rhs._duration
    }
    
    public static func + (lhs: VirtualTime, rhs: VirtualTimeInterval) -> VirtualTime {
        .init(lhs._time + rhs._duration)
    }
    
    public static func - (lhs: VirtualTime, rhs: VirtualTimeInterval) -> VirtualTime {
        .init(lhs._time - rhs._duration)
    }
    
    public static func += (lhs: inout VirtualTime, rhs: VirtualTimeInterval) {
        lhs._time += rhs._duration
    }
    
    public static func -= (lhs: inout VirtualTime, rhs: VirtualTimeInterval) {
        lhs._time -= rhs._duration
    }
}

// MARK: - Int initializer

extension Int {
    init(_ value: VirtualTimeInterval) {
        self.init(value._duration)
    }
}
