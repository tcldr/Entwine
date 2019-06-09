
import Combine
import Foundation

// MARK: - Behavior value definition

public enum TestablePublisherBehavior { case hot, cold }

// MARK: - Event value definition

public struct TestablePublisherEvent <Element> {
    public let time: VirtualTime
    public let value: Element
}

// MARK: - Publisher definition

public struct TestablePublisher<Output, Failure: Error>: Publisher {
    
    private let testScheduler: TestScheduler
    private let behavior: TestablePublisherBehavior
    private let recordedEvents: [TestablePublisherEvent<Output>]
    
    init(testScheduler: TestScheduler, behavior: TestablePublisherBehavior, recordedEvents: [TestablePublisherEvent<Output>]) {
        self.testScheduler = testScheduler
        self.recordedEvents = recordedEvents
        self.behavior = behavior
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
        subscriber.receive(subscription: TestablePublisherSubscription(sink: subscriber, testScheduler: testScheduler, behavior: behavior, recordedEvents: recordedEvents))
    }
}

// MARK: - Subscription definition

fileprivate class TestablePublisherSubscription<Sink: Subscriber>: Subscription {
    
    private var queue: SinkOutputQueue<Sink>
    
    private var cancellables = [AnyCancellable]()
    private var capacity = Subscribers.Demand.none
    private var queuedItems = [Sink.Input]()
    
    init(sink: Sink, testScheduler: TestScheduler, behavior: TestablePublisherBehavior, recordedEvents: [TestablePublisherEvent<Sink.Input>]) {
        
        self.queue = SinkOutputQueue(sink: sink)
        
        recordedEvents.forEach { recordedEvent in
            guard behavior == .cold || testScheduler.now <= recordedEvent.time else { return }
            let due = behavior == .cold ? testScheduler.now + recordedEvent.time : recordedEvent.time
            let cancellable = testScheduler.schedule(after: due, interval: 0) { [unowned self] in
                self.queue.enqueueItem(recordedEvent.value)
            }
            cancellables.append(AnyCancellable { cancellable.cancel() })
        }
    }
    
    deinit {
        cancel()
    }
    
    func request(_ demand: Subscribers.Demand) {
        queue.request(demand)
    }
    
    func cancel() {
        cancellables.forEach { $0.cancel() }
        queue.sink.receive(completion: .finished)
    }
}

// MARK: - SinkOutputQueue definition

struct SinkOutputQueue<Sink: Subscriber> {
    
    let sink: Sink
    
    private var queuedItems = [Sink.Input]()
    private var capacity = Subscribers.Demand.none
    
    init(sink: Sink) {
        self.sink = sink
    }
    
    mutating func enqueueItem(_ item: Sink.Input) {
        queuedItems.append(item)
        dispatchPendingItems()
    }
    
    mutating func request(_ demand: Subscribers.Demand) {
        capacity += demand
        dispatchPendingItems()
    }
    
    private mutating func dispatchPendingItems() {
        while !queuedItems.isEmpty {
            guard capacity > .none else { break }
            capacity += (sink.receive(queuedItems.removeFirst()) - 1)
        }
    }
}
