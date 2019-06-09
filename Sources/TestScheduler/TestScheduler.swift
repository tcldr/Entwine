
import Combine

// MARK: - TestScheduler definition

public class TestScheduler {
    
    public struct Configuration {
        
        /// Absolute time when to create tested observable sequence.
        public var created: VirtualTime = 100
        /// Absolute time when to subscribe to tested observable sequence.
        public var subscribed: VirtualTime = 200
        /// Absolute time when to cancel a subscription to an observable sequence.
        public var cancelled: VirtualTime = 1000
        
        public var subscriberOptions = TestableSubscriberOptions.default
        
        public static let `default` = Configuration()
    }
    
    private var currentTime = VirtualTime(0)
    private var lastTaskId = -1
    private var schedulerQueue: PriorityQueue<TestSchedulerTask>
    
    public init(initialClock: VirtualTime = 0) {
        self.schedulerQueue = PriorityQueue(ascending: true, startingValues: [])
        self.currentTime = initialClock
    }
    
    public func start<P: Publisher>(configuration: Configuration = .default, create: @escaping () -> P) -> TestableSubscriber<P> {
        
        reset()
        
        let subscriber = TestableSubscriber<P>(scheduler: self, options: configuration.subscriberOptions)
        
        var source: AnyPublisher<P.Output, P.Failure>?
        
        schedule(after: configuration.created, tolerance: minimumTolerance, options: nil) {
            source = create().eraseToAnyPublisher()
        }
        schedule(after: configuration.subscribed, tolerance: minimumTolerance, options: nil) {
            source!.subscribe(subscriber)
        }
        schedule(after: configuration.cancelled, tolerance: minimumTolerance, options: nil) {
            subscriber.cancel()
        }
        
        resume()
        
        return subscriber
    }
    
    public func createTestableHotPublisher<Value, Failure: Error>(_ events: [TestablePublisherEvent<Value>]) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .hot, recordedEvents: events)
    }
    
    public func createTestableColdPublisher<Value, Failure: Error>(_ events: [TestablePublisherEvent<Value>]) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .cold, recordedEvents: events)
    }
    
    func resume() {
        while let next = findNext() {
            if next.time > currentTime {
                currentTime = next.time
            }
            next.action()
            schedulerQueue.remove(next)
        }
    }
    
    func reset(initialClock: VirtualTime = 0) {
        self.schedulerQueue = PriorityQueue(ascending: true, startingValues: [])
        self.currentTime = initialClock
        self.lastTaskId = -1
    }
    
    private func findNext() -> TestSchedulerTask? {
        schedulerQueue.peek()
    }
    
    private func nextTaskId() -> Int {
        lastTaskId += 1
        return lastTaskId
    }
}

// MARK: - TestScheduler Scheduler conformance

extension TestScheduler: Scheduler {
    
    public typealias SchedulerTimeType = VirtualTime
    public typealias SchedulerOptions = Never
    
    /// Returns this scheduler's definition of the current moment in time.
    public var now: VirtualTime { currentTime }
    
    /// Returns the minimum tolerance allowed by the scheduler.
    public var minimumTolerance: VirtualTimeInterval { 1 }
    
    /// Performs the action at the next possible opportunity.
    public func schedule(options: Never?, _ action: @escaping () -> Void) {
        schedulerQueue.push(TestSchedulerTask(id: nextTaskId(), time: currentTime, action: action))
    }
    
    /// Performs the action at some time after the specified date.
    public func schedule(after date: VirtualTime, tolerance: VirtualTimeInterval, options: Never?, _ action: @escaping () -> Void) {
        schedulerQueue.push(TestSchedulerTask(id: nextTaskId(), time: date, action: action))
    }
    
    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    public func schedule(after date: VirtualTime, interval: VirtualTimeInterval, tolerance: VirtualTimeInterval, options: Never?, _ action: @escaping () -> Void) -> Cancellable {
        let task = TestSchedulerTask(id: nextTaskId(), time: date, action: action)
        schedulerQueue.push(task)
        return AnyCancellable {
            self.schedulerQueue.remove(task)
        }
    }
}

// MARK: - TestSchedulerTask definition

struct TestSchedulerTask {
    
    typealias Action = () -> Void
    
    let id: Int
    let time: VirtualTime
    let action: Action
    
    init(id: Int, time: VirtualTime, action: @escaping Action) {
        self.id = id
        self.time = time
        self.action = action
    }
}

// MARK: - TestSchedulerTask Comparable conformance

extension TestSchedulerTask: Comparable {
    
    static func < (lhs: TestSchedulerTask, rhs: TestSchedulerTask) -> Bool {
        (lhs.time, lhs.id) < (rhs.time, rhs.id)
    }
    
    static func == (lhs: TestSchedulerTask, rhs: TestSchedulerTask) -> Bool {
        lhs.id == rhs.id
    }
}
