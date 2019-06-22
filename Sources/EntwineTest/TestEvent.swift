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
import Entwine

public struct TestEvent <Signal: SignalConvertible> {
    
    public let time: VirtualTime
    public let signal: Signal
    
    public init(_ time: VirtualTime, _ signal: Signal) {
        self.time = time
        self.signal = signal
    }
    
    public static func subscription(_ time: VirtualTime) -> TestEvent<Signal> {
        TestEvent(time, .init(.subscription))
    }
    
    public static func input(_ time: VirtualTime, _ value: Signal.Input) -> TestEvent<Signal> {
        TestEvent(time, .init(.input(value)))
    }
    
    public static func completion(_ time: VirtualTime, _ completion: Subscribers.Completion<Signal.Failure>) -> TestEvent<Signal> {
        TestEvent(time, .init(.completion(completion)))
    }
    
    public static func from<S: Sequence>(_ sequence: S) -> [TestEvent<Signal>] where S.Element == (VirtualTime, Signal) {
        sequence.map { TestEvent($0.0, $0.1) }
    }
}

// MARK: - Equatable conformance

extension TestEvent: Equatable where Signal: Equatable {}

// MARK: - CustomDebugStringConvertible conformance

extension TestEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "SignalEvent(\(time), \(signal))"
    }
}
