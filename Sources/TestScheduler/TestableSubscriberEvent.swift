
import Combine

public struct TestableSubscriberEvent <Input, Failure: Error> {
    
    public let time: VirtualTime
    public let signal: Signal<Input, Failure>
    
    public init(_ time: VirtualTime, _ signal: Signal<Input, Failure>) {
        self.time = time
        self.signal = signal
    }
}

// MARK: - Equatable conformance

extension TestableSubscriberEvent: Equatable where Input: Equatable, Failure: Equatable {}

// MARK: - CustomDebugStringConvertible conformance

extension TestableSubscriberEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "TestableSubscriberEvent(\(time), \(signal))"
    }
}
