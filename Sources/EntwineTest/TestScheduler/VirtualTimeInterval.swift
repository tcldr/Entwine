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

import Combine

// MARK: - VirtualTimeInterval value definition

public struct VirtualTimeInterval {
    
    internal var _duration: Int
    
    public init(_ duration: Int) {
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
