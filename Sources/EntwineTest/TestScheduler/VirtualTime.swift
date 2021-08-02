//
//  Entwine
//  https://github.com/tcldr/Entwine
//
//  Copyright © 2019 Tristan Celder. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


// MARK: - VirtualTime value definition

/// Unit of virtual time consumed by the `TestScheduler`
public struct VirtualTime: Hashable {
    
    internal var _time: Int
    
    public init(_ time: Int) {
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
