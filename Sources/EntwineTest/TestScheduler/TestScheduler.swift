//
//  Entwine
//  https://github.com/tcldr/Entwine
//
//  Copyright © 2019 Tristan Celder. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

//  Based on RxSwift's `TestScheduler`
//  Copyright © 2015 Krunoslav Zaher All rights reserved.
//  https://github.com/ReactiveX/RxSwift

import Entwine
import Combine

// MARK: - TestScheduler definition


/// A `Scheduler` thats uses `VirtualTime` to schedule its tasks.
///
/// A special, non thread-safe scheduler for testing operators that require a scheduler without introducing
/// real concurrency. Faciliates a recreatable sequence of tasks executed within 'virtual time'.
///
public class TestScheduler {
    
    /// Configuration values for  a`TestScheduler` test run.
    public struct Configuration {
        /// Determines if the scheduler starts the test immediately
        public var pausedOnStart = false
        /// Absolute `VirtualTime`at which `Publisher` factory is invoked.
        public var created: VirtualTime = 100
        /// Absolute `VirtualTime` at which initialised `Publisher` is subscribed to.
        public var subscribed: VirtualTime = 200
        /// Absolute `VirtualTime` at which subscription to `Publisher` is cancelled.
        public var cancelled: VirtualTime = 900
        /// Options for the generated `TestableSubscriber`
        public var subscriberOptions = TestableSubscriberOptions.default
        
        public static let `default` = Configuration()
    }
    
    private var currentTime = VirtualTime(0)
    private var lastTaskId = -1
    private var schedulerQueue: PriorityQueue<TestSchedulerTask>
    
    /// Initialises the scheduler with the given commencement time
    public init(initialClock: VirtualTime = 0) {
        self.schedulerQueue = PriorityQueue(ascending: true, startingValues: [])
        self.currentTime = initialClock
    }
    
    /// Schedules the creation and subscription of an arbitrary `Publisher` to a `TestableSubscriber`, and
    /// finally the subscription's subsequent cancellation.
    ///
    /// The default `Configuration`:
    /// - Creates the publisher (executes the supplied publisher factory) at `100`
    /// - Subscribes to the publisher at `200`
    /// - Cancels the subscription at `900`
    /// - Starts the scheduler immediately.
    /// - Uses `TestableSubscriberOptions.default` for the subscriber configuration.
    ///
    /// - Parameters:
    ///   - configuration: The parameters of the test subscription including scheduling details
    ///   - create: A factory function that returns the publisher to be subscribed to
    /// - Returns: A `TestableSubscriber` that contains, or is scheduled to contain, the output of the publisher subscription.
    public func start<P: Publisher>(configuration: Configuration = .default, create: @escaping () -> P) -> TestableSubscriber<P.Output, P.Failure> {
        
        let subscriber = createTestableSubscriber(P.Output.self, P.Failure.self, options: configuration.subscriberOptions)
        var source: AnyPublisher<P.Output, P.Failure>!
        
        schedule(after: configuration.created, tolerance: minimumTolerance, options: nil) {
            source = create().eraseToAnyPublisher()
        }
        schedule(after: configuration.subscribed, tolerance: minimumTolerance, options: nil) {
            source.subscribe(subscriber)
        }
        schedule(after: configuration.cancelled, tolerance: minimumTolerance, options: nil) {
            subscriber.cancel()
        }
        
        guard !configuration.pausedOnStart else {
            return subscriber
        }
        
        defer { resume() }
        
        return subscriber
    }
    
    /// Initialises a `TestablePublisher` with events scheduled in absolute time.
    ///
    /// Creates a `TestablePublisher` and schedules the supplied `TestSequence` to occur in
    /// absolute time. Sequence elements with virtual times in the 'past' will be ignored.
    ///
    /// - Warning: This method will produce an assertion failure if the supplied `TestSequence` includes
    /// a `Signal.subscription` element. Subscription time is dictated by the subscriber and can not be
    /// predetermined by the publisher.
    ///
    /// - Parameter sequence: The sequence of values the publisher should produce
    /// - Returns: A `TestablePublisher` loaded with the supplied `TestSequence`.
    public func createAbsoluteTestablePublisher<Value, Failure: Error>(_ sequence: TestSequence<Value, Failure>) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .absolute, testSequence: sequence)
    }
    
    /// Initialises a `TestablePublisher` with events scheduled in relative time.
    ///
    /// Creates a `TestablePublisher` and schedules the supplied `TestSequence` to occur in
    /// absolute time.
    ///
    /// - Warning: This method will produce an assertion failure if the supplied `TestSequence` includes
    /// a `Signal.subscription` element. Subscription time is dictated by the subscriber and can not be
    /// predetermined by the publisher.
    ///
    /// - Parameter sequence: The sequence of values the publisher should produce
    /// - Returns: A `TestablePublisher` loaded with the supplied `TestSequence`.
    public func createRelativeTestablePublisher<Value, Failure: Error>(_ sequence: TestSequence<Value, Failure>) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .relative, testSequence: sequence)
    }
    
    
    /// Produces a `TestableSubscriber` pre-populated with this scheduler.
    ///
    /// - Parameters:
    ///   - inputType: The `Input` associated type for the produced `Subscriber`
    ///   - failureType: The `Failure` associated type for the produced `Subscriber`
    ///   - options: Behavior options for the produced `Subscriber`
    /// - Returns: A configured `TestableSubscriber`.
    public func createTestableSubscriber<Input, Failure>(_ inputType: Input.Type, _ failureType: Failure.Type, options: TestableSubscriberOptions = .default) -> TestableSubscriber<Input, Failure> {
        return TestableSubscriber(scheduler: self, options: options)
    }
    
    /// Performs all the actions in the scheduler's queue, in time order followed by submission order, until no
    /// more actions remain.
    public func resume() {
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
    
    public var now: VirtualTime { currentTime }
    
    public var minimumTolerance: VirtualTimeInterval { 1 }
    
    public func schedule(options: Never?, _ action: @escaping () -> Void) {
        schedulerQueue.push(TestSchedulerTask(id: nextTaskId(), time: currentTime, action: action))
    }
    
    public func schedule(after date: VirtualTime, tolerance: VirtualTimeInterval, options: Never?, _ action: @escaping () -> Void) {
        schedulerQueue.push(TestSchedulerTask(id: nextTaskId(), time: date, action: action))
    }
    
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
