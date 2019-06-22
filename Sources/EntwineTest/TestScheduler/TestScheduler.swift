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

import Entwine
import Combine

// MARK: - TestScheduler definition

public class TestScheduler {
    
    public struct Configuration {
        public var pausedOnStart = false
        /// Absolute time when to create tested observable sequence.
        public var created: VirtualTime = 100
        /// Absolute time when to subscribe to tested observable sequence.
        public var subscribed: VirtualTime = 200
        /// Absolute time when to cancel a subscription to an observable sequence.
        public var cancelled: VirtualTime = 900
        
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
    
    public func start<P: Publisher>(configuration: Configuration = .default, create: @escaping () -> P) -> TestableSubscriber<P.Output, P.Failure> {
        
        var subscriber = createTestableSubscriber(P.Output.self, P.Failure.self, options: configuration.subscriberOptions)
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
    
    
    
    public func createTestableHotPublisher<Value, Failure: Error>(_ sequence: TestSequence<Value, Failure>) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .hot, testSequence: sequence)
    }
    
    public func createTestableColdPublisher<Value, Failure: Error>(_ sequence: TestSequence<Value, Failure>) -> TestablePublisher<Value, Failure> {
        return TestablePublisher(testScheduler: self, behavior: .cold, testSequence: sequence)
    }
    
    public func createTestableSubscriber<Input, Failure>(_ inputType: Input.Type, _ failureType: Failure.Type, options: TestableSubscriberOptions = .default) -> TestableSubscriber<Input, Failure> {
        return TestableSubscriber(scheduler: self, options: options)
    }
    
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
