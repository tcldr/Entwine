
import Combine

// MARK: - SinkOutputQueue definition

class SinkOutputQueue<Input, Failure: Error> {
    
    private enum Status { case idle, active }
    
    private var sink: AnySubscriber<Input, Failure>?
    
    private var queuedItems = LinkedListQueue<Input>()
    private var status = Status.idle
    private var capacity = Subscribers.Demand.none
    
    var isComplete: Bool { (sink == nil) }
    
    init<S: Subscriber>(sink: S) where S.Input == Input, S.Failure == Failure {
        self.sink = sink.eraseToAnySubscriber()
    }
    
    func enqueueItem(_ item: Input) {
        guard !isComplete else { return }
        queuedItems.enqueue(item)
        dispatchPendingItems()
    }
    
    func enqueueItems<S: Sequence>(_ items: S) where S.Element == Input {
        guard !isComplete else { return }
        items.forEach { queuedItems.enqueue($0) }
        dispatchPendingItems()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard !isComplete else { return }
        capacity += demand
        dispatchPendingItems()
    }
    
    func complete(_ completion: Subscribers.Completion<Failure>) {
        guard let sink = sink else { return }
        self.sink = nil
        sink.receive(completion: completion)
    }
    
    private func dispatchPendingItems() {
        guard status == .idle else { return }
        status = .active
        while capacity > .none, let sink = sink, let nextInput = queuedItems.next() {
            capacity += (sink.receive(nextInput) - 1)
        }
        status = .idle
    }
}
