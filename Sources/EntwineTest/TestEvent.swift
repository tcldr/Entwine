
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
