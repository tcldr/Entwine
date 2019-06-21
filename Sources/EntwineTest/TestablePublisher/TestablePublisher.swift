
import Combine
import Entwine
import Foundation

// MARK: - Behavior value definition

public enum TestablePublisherBehavior { case hot, cold }

// MARK: - Publisher definition

public struct TestablePublisher<Output, Failure: Error>: Publisher {
    
    private let testScheduler: TestScheduler
    private let testSequence: TestSequence<Output, Failure>
    private let behavior: TestablePublisherBehavior
    
    init(testScheduler: TestScheduler, behavior: TestablePublisherBehavior, testSequence: TestSequence<Output, Failure>) {
        self.testScheduler = testScheduler
        self.testSequence = testSequence
        self.behavior = behavior
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
        subscriber.receive(subscription:
            TestablePublisherSubscription(
                sink: subscriber, testScheduler: testScheduler, behavior: behavior, testSequence: testSequence))
    }
}

// MARK: - Subscription definition

fileprivate final class TestablePublisherSubscription<Sink: Subscriber>: Subscription {
    
    private let linkedList = LinkedList<Int>.empty
    private let queue: SinkQueue<Sink>
    private var cancellables = [AnyCancellable]()
    
    init(sink: Sink, testScheduler: TestScheduler, behavior: TestablePublisherBehavior, testSequence: TestSequence<Sink.Input, Sink.Failure>) {
        
        self.queue = SinkQueue(sink: sink)
        
        testSequence.events.forEach { recordedEvent in
            
            guard behavior == .cold || testScheduler.now <= recordedEvent.time else { return }
            let due = behavior == .cold ? testScheduler.now + recordedEvent.time : recordedEvent.time
            
            switch recordedEvent.signal {
            case .subscription:
                assertionFailure("Illegal input. `.subscription` events will be ignored. \(recordedEvent)")
                break
            case .input(let value):
                let cancellable = testScheduler.schedule(after: due, interval: 0) { [unowned self] in
                    _ = self.queue.enqueue(value)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            case .completion(let completion):
                let cancellable = testScheduler.schedule(after: due, interval: 0) { [unowned self] in
                    self.queue.expediteCompletion(completion)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            }
        }
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    func request(_ demand: Subscribers.Demand) {
        _ = queue.requestDemand(demand)
    }
    
    func cancel() {
        queue.expediteCompletion(.finished)
    }
}
