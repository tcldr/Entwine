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

// MARK: - Signal value definition

public enum Signal <Input, Failure: Error> {
    case subscription
    case input(Input)
    case completion(Subscribers.Completion<Failure>)
}

// MARK: - Equatable conformance

extension Signal: Equatable where Input: Equatable, Failure: Equatable {
    
    public static func ==(lhs: Signal<Input, Failure>, rhs: Signal<Input, Failure>) -> Bool {
        switch (lhs, rhs) {
        case (.subscription, .subscription):
            return true
        case (.input(let lhsInput), .input(let rhsInput)):
            return (lhsInput == rhsInput)
        case (.completion(let lhsCompletion), .completion(let rhsCompletion)):
            return completionsMatch(lhs: lhsCompletion, rhs: rhsCompletion)
        default:
            return false
        }
    }
    
    fileprivate static func completionsMatch(lhs: Subscribers.Completion<Failure>, rhs: Subscribers.Completion<Failure>) -> Bool {
        switch (lhs, rhs) {
        case (.finished, .finished):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return (lhsError == rhsError)
        default:
            return false
        }
    }
}

public protocol SignalConvertible {
    
    associatedtype Input
    associatedtype Failure: Error
    
    init(_ signal: Signal<Input, Failure>)
    var signal: Signal<Input, Failure> { get }
}

extension Signal: SignalConvertible {
    
    public init(_ signal: Signal<Input, Failure>) {
        self = signal
    }
    
    public var signal: Signal<Input, Failure> {
        return self
    }
}
