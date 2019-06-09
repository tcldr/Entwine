
import Combine

// MARK: - VirtualTime value definition

public struct VirtualTime: Hashable {
    
    internal var _time: Int
    
    init(_ time: Int) {
        _time = time
    }
}

// MARK: - SignedNumeric conformance

extension VirtualTime: SignedNumeric {
    
    public typealias Magnitude = Int
    
    public var magnitude: Int { Int(_time.magnitude) }
    
    public init?<T>(exactly source: T) where T : BinaryInteger {
        guard let value = Int(exactly: source) else { return nil }
        self.init(value)
    }
    
    public static func * (lhs: VirtualTime, rhs: VirtualTime) -> VirtualTime {
        .init(lhs._time * rhs._time)
    }
    
    public static func *= (lhs: inout VirtualTime, rhs: VirtualTime) {
        lhs._time *= rhs._time
    }
    
    public static func + (lhs: VirtualTime, rhs: VirtualTime) -> VirtualTime {
        .init(lhs._time + rhs._time)
    }
    
    public static func - (lhs: VirtualTime, rhs: VirtualTime) -> VirtualTime {
        .init(lhs._time - rhs._time)
    }
    
    public static func += (lhs: inout VirtualTime, rhs: VirtualTime) {
        lhs._time += rhs._time
    }
    
    public static func -= (lhs: inout VirtualTime, rhs: VirtualTime) {
        lhs._time -= rhs._time
    }
}

// MARK: - Strideable conformance

extension VirtualTime: Strideable {
    
    public typealias Stride = VirtualTimeInterval
    
    public func distance(to other: VirtualTime) -> VirtualTimeInterval {
        .init(other._time - _time)
    }
    
    public func advanced(by n: VirtualTimeInterval) -> VirtualTime {
        .init(_time + n._duration)
    }
}

// MARK: - ExpressibleByIntegerLiteral conformance

extension VirtualTime: ExpressibleByIntegerLiteral {
    
    public typealias IntegerLiteralType = Int
    
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

// MARK: - CustomDebugStringConvertible conformance

extension VirtualTime: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "\(_time)"
    }
}

// MARK: - Int initializer

extension Int {
    init(_ value: VirtualTime) {
        self.init(value._time)
    }
}
