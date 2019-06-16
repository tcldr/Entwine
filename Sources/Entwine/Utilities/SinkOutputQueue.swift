
import Combine

// MARK: - SinkOutputQueue definition

public class SinkOutputQueue<Input, Failure: Error> {
    
    enum Status { case idle, active }
    
    var sink: AnySubscriber<Input, Failure>?
    
    var queuedItems = LinkedListQueue<Input>()
    var status = Status.idle
    var capacity = Subscribers.Demand.none
    
    public var isComplete: Bool { (sink == nil) }
    
    public init<S: Subscriber>(sink: S) where S.Input == Input, S.Failure == Failure {
        self.sink = sink.eraseToAnySubscriber()
    }
    
    public func enqueueItem(_ item: Input) {
        guard !isComplete else { return }
        queuedItems.enqueue(item)
        dispatchPendingItems()
    }
    
    public func enqueueItems<S: Sequence>(_ items: S) where S.Element == Input {
        guard !isComplete else { return }
        items.forEach { queuedItems.enqueue($0) }
        dispatchPendingItems()
    }
    
    public func request(_ demand: Subscribers.Demand) {
        guard !isComplete else { return }
        capacity += demand
        dispatchPendingItems()
    }
    
    public func complete(_ completion: Subscribers.Completion<Failure>) {
        guard let sink = sink else { return }
        self.sink = nil
        sink.receive(completion: completion)
    }
    
    func dispatchPendingItems() {
        guard status == .idle else { return }
        status = .active
        while capacity > .none, let sink = sink, let nextInput = queuedItems.next() {
            capacity += (sink.receive(nextInput) - 1)
        }
        status = .idle
    }
}
