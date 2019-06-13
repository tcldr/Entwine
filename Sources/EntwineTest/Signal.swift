//
//  File.swift
//  
//
//  Created by Tristan Celder on 11/06/2019.
//

import Combine

// MARK: - Signal value definition

public enum Signal <Input, Failure: Error> {
    case subscribe
    case input(Input)
    case completion(Subscribers.Completion<Failure>)
}

// MARK: - CustomDebugStringConvertible conformance

extension Signal: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .subscribe:
            return ".subscribe"
        case .input(let input):
            return ".input(\(input))"
        case .completion(let completion):
            return ".completion(\(completion))"
        }
    }
}

// MARK: - Equatable conformance

extension Signal: Equatable where Input: Equatable, Failure: Equatable {
    
    public static func ==(lhs: Signal<Input, Failure>, rhs: Signal<Input, Failure>) -> Bool {
        switch (lhs, rhs) {
        case (.subscribe, .subscribe):
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
