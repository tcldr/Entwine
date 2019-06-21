
import Combine
import Entwine

public struct SignalEvent <Signal: SignalConvertible> {
    
    public let time: VirtualTime
    public let signal: Signal
    
    public init(_ time: VirtualTime, _ signal: Signal) {
        self.time = time
        self.signal = signal
    }
    
    public static func subscription(_ time: VirtualTime) -> SignalEvent<Signal> {
        SignalEvent(time, .init(.subscription))
    }
    
    public static func input(_ time: VirtualTime, _ value: Signal.Input) -> SignalEvent<Signal> {
        SignalEvent(time, .init(.input(value)))
    }
    
    public static func completion(_ time: VirtualTime, _ completion: Subscribers.Completion<Signal.Failure>) -> SignalEvent<Signal> {
        SignalEvent(time, .init(.completion(completion)))
    }
}

// MARK: - Equatable conformance

extension SignalEvent: Equatable where Signal: Equatable {}

// MARK: - CustomDebugStringConvertible conformance

extension SignalEvent: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "SignalEvent(\(time), \(signal))"
    }
}
