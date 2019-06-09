
import Combine

// MARK: - TestableSubscriberEvent value definition

public enum TestableSubscriberEvent <Input, Failure: Error> {
    case subscribe(time: VirtualTime)
    case input(time: VirtualTime, Input)
    case completion(time: VirtualTime, Subscribers.Completion<Failure>)
}

// MARK: - Equatable conformance

extension TestableSubscriberEvent: Equatable where Input: Equatable, Failure: Equatable {
    
    public static func ==(lhs: TestableSubscriberEvent<Input, Failure>, rhs: TestableSubscriberEvent<Input, Failure>) -> Bool {
        switch (lhs, rhs) {
        case (.subscribe(let lhsTime), .subscribe(let rhsTime)):
            return (lhsTime == rhsTime)
        case (.input(let lhsInput), .input(let rhsInput)):
            return (lhsInput == rhsInput)
        case (.completion(let lhsTime, let lhsCompletion), .completion(let rhsTime, let rhsCompletion)):
            return (lhsTime == rhsTime) && completionsMatch(lhs: lhsCompletion, rhs: rhsCompletion)
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

// MARK: - CustomDebugStringConvertible conformance

extension TestableSubscriberEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .subscribe(time: let time):
            return ".subscribe(time: \(time))"
        case .input(time: let time, let input):
            return ".input(time: \(time), \(input))"
        case .completion(time: let time, let completion):
            return ".input(time: \(time), \(completion))"
        }
    }
}
