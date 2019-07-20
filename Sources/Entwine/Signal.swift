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

/// A materialized representation of a `Publisher`s output.
///
/// Upon a call to subscribe, a legal `Publisher` produces signals in strictly the following order:
/// - Exactly one 'subscription' signal.
/// - Followed by zero or more 'input' signals.
/// - Terminated finally by a single 'completion' signal.
public enum Signal <Input, Failure: Error> {
    /// Sent by a `Publisher` to a `Subscriber` in acknowledgment of the `Subscriber`'s
    /// subscription request.
    case subscription
    /// The payload of a subscription. Zero to many `.input(_)` signals may be produced
    /// during the lifetime of a `Subscriber`'s subscription to a `Publisher`.
    case input(Input)
    /// The final signal sent to a `Subscriber` during a subscription to a `Publisher`.
    /// Indicates termination of the stream as well as the reason.
    case completion(Subscribers.Completion<Failure>)
}

// MARK: - Signal extensions

public extension Signal {
    /// Whether the signal indicates sequence completion
    var isCompletion: Bool {
        guard case .completion(_) = self else { return false }
        return true
    }
    
    /// Returns a signal with a transformed input type and input element
    /// - Parameter transform: A mapping closure. `transform` accepts an element of this signal's input type
    /// as its parameter and returns a transformed value of the same or of a different type.
    /// - Returns: A signal with a transformed input type and input element
    func mapInput<T>(_ transform: (Input) -> T) -> Signal<T, Failure> {
        switch self {
        case .input(let value):             return .input(transform(value))
        case .completion(let completion):   return .completion(completion)
        case .subscription:                 return .subscription
        }
    }
    
    /// Returns a signal with a transformed failure type and completion element
    /// - Parameter transform: A mapping closure. `transform` accepts an element of this signal's failure type
    /// as its parameter and returns a transformed error of the same or of a different type.
    /// - Returns: A signal with a transformed failure type and completion element
    func mapFailure<T: Error>(_ transform: (Failure) -> T) -> Signal<Input, T> {
        switch self {
        case .completion(let completion):
            guard case .failure(let error) = completion else {
                return .completion(.finished)
            }
            return .completion(.failure(transform(error)))
        case .input(let value):             return .input(value)
        case .subscription:                 return .subscription
        }
    }
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

/// A type that can be converted into a `Signal`
public protocol SignalConvertible {
    
    /// The `Input` type of the produced `Signal`
    associatedtype Input
    /// The `Failure` type of the produced `Signal`
    associatedtype Failure: Error
    
    init(_ signal: Signal<Input, Failure>)
    /// The converted `Signal`
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
