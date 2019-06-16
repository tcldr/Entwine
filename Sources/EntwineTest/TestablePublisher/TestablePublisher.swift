
import Combine
import Entwine
import Foundation

// MARK: - Behavior value definition

public enum TestablePublisherBehavior { case hot, cold }

// MARK: - Event value definition

public struct TestablePublisherEvent <Element> {
    
    public init(time: VirtualTime, _ value: Element) {
        self.time = time
        self.value = value
    }
    
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
        subscriber.receive(subscription: createSubscription(subscriber: subscriber))
    }
    
    func createSubscription<S: Subscriber>(subscriber: S) -> Subscription where S.Failure == Failure, S.Input == Output {
        TestablePublisherSubscription(sink: subscriber, testScheduler: testScheduler, behavior: behavior, recordedEvents: recordedEvents)
    }
}

// MARK: - Subscription definition

fileprivate final class TestablePublisherSubscription<Sink: Subscriber>: Subscription {
    
    private let linkedList = LinkedList<Int>.empty
    private let queue: Entwine.SinkOutputQueue<Sink.Input, Sink.Failure>
    private var cancellables = [AnyCancellable]()
    private let serialDispatchQueue = DispatchQueue.init(label: "com.celder.entwine.TestablePublisherSubscription.serialDispatchQueue")
    
    init(sink: Sink, testScheduler: TestScheduler, behavior: TestablePublisherBehavior, recordedEvents: [TestablePublisherEvent<Sink.Input>]) {
        
        self.queue = Entwine.SinkOutputQueue(sink: sink)
        
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
        cancellables.forEach { $0.cancel() }
    }
    
    func request(_ demand: Subscribers.Demand) {
        queue.request(demand)
    }
    
    func cancel() {
        queue.complete(.finished)
    }
}
