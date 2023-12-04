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

#if canImport(Combine)

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class TestSchedulerTests: XCTestCase {
    
    func testSchedulerTasksSortSensibly() {
        
        // this should order by time, then id
        
        let t0 = TestSchedulerTask(id: 0, time: 200, interval: 0, action: {})
        let t1 = TestSchedulerTask(id: 1, time: 200, interval: 0, action: {})
        let t2 = TestSchedulerTask(id: 2, time: 300, interval: 0, action: {})
        let t3 = TestSchedulerTask(id: 3, time: 300, interval: 0, action: {})
        let t4 = TestSchedulerTask(id: 4, time: 400, interval: 0, action: {})
        let t5 = TestSchedulerTask(id: 5, time: 400, interval: 0, action: {})
        let t6 = TestSchedulerTask(id: 6, time: 100, interval: 0, action: {})
        let t7 = TestSchedulerTask(id: 7, time: 100, interval: 0, action: {})
        
        let unsorted = [t0, t1, t2, t3, t4, t5, t6, t7,]
        let sorted = [t6, t7, t0, t1, t2, t3, t4, t5,]
        
        XCTAssertEqual(unsorted.sorted(), sorted)
    }
    
    func testSchedulerInvokesBasicTask() {
        
        let subject = TestScheduler(initialClock: 0)
        var scheduledTaskDidRun = false
        
        subject.schedule { scheduledTaskDidRun = true }
        
        subject.resume()
        
        XCTAssert(scheduledTaskDidRun)
    }
    
    func testSchedulerInvokesTasksInTimeOrder() {
        
        let subject = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        subject.schedule(after: 300) { times.append(subject.now) }
        subject.schedule(after: 200) { times.append(subject.now) }
        subject.schedule(after: 100) { times.append(subject.now) }
        
        subject.resume()
        
        XCTAssertEqual(times, [100, 200, 300,])
    }

    func testSchedulerAdvancesToTasksTime() {

        let subject = TestScheduler(initialClock: 0)
        var changedValue = 0

        subject.schedule(after: 300) { changedValue = 300 }
        subject.schedule(after: 200) { changedValue = 200 }
        subject.schedule(after: 100) { changedValue = 100 }

        subject.advance(to: 200)

        XCTAssertEqual(changedValue, 200)
    }

    func testSchedulerAdvancesToTasksByTimeInterval() {

        let subject = TestScheduler(initialClock: 0)
        var changedValue = 0

        subject.schedule(after: 300) { changedValue = 300 }
        subject.schedule(after: 200) { changedValue = 200 }
        subject.schedule(after: 100) { changedValue = 100 }

        subject.advance(to: 100)
        XCTAssertEqual(changedValue, 100)
        subject.advance(by: 100)
        XCTAssertEqual(changedValue, 200)
    }

    func testSchedulerInvokesDeferredTask() {
        
        let subject = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        subject.schedule(after: 100) {
            times.append(subject.now)
            subject.schedule(after: subject.now + 100) {
                times.append(subject.now)
            }
        }
        
        subject.resume()
        
        XCTAssertEqual(times, [100, 200,])
    }
    
    func testSchedulerInvokesDeferredTaskScheduledForPastImmediately() {
        
        let subject = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        subject.schedule(after: 100) {
            times.append(subject.now)
            subject.schedule(after: subject.now - 100) {
                times.append(subject.now)
            }
        }
        
        subject.resume()
        
        XCTAssertEqual(times, [100, 100,])
    }
    
    func testSchedulerRemovesCancelledTasks() {
        
        let subject = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        subject.schedule(after: 100) {
            times.append(subject.now)
        }
        let cancellable = subject.schedule(after: 200, interval: 0) {
            times.append(subject.now)
        }
        subject.schedule(after: 300) {
            times.append(subject.now)
        }
        
        cancellable.cancel()
        subject.resume()
        
        XCTAssertEqual(times, [100, 300,])
    }
    
    func testSchedulerQueues() {
        
        let subject = TestScheduler(initialClock: 0)
        
        let publisher1 = PassthroughSubject<Int, Never>()
        let publisher2 = PassthroughSubject<Int, Never>()
        
        let results = subject.createTestableSubscriber(Int.self, Never.self)
        
        subject.schedule(after: 100) { publisher1.subscribe(results) }
        subject.schedule(after: 110) { publisher1.send(0) }
        subject.schedule(after: 200) { publisher2.subscribe(results) }
        subject.schedule(after: 210) { publisher2.send(1) }
        subject.schedule(after: 310) { publisher1.send(2) }
        
        subject.resume()
        
        let expected: TestSequence<Int, Never> = [
            (100, .subscription),
            (110, .input(0)),
            (310, .input(2)),
        ]
        
        XCTAssertEqual(expected, results.recordedOutput)
    }
    
    func testFiresEventsScheduledBeforeStartCalled() {
        
        let subject = TestScheduler(initialClock: 0)
        
        let publisher1 = PassthroughSubject<Int, Never>()
        
        subject.schedule(after: 300) { publisher1.send(0) }
        subject.schedule(after: 400) { publisher1.send(1) }
        subject.schedule(after: 500) { publisher1.send(2) }
        
        let testableSubscriber = subject.start { publisher1 }
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .input(0)),
            (400, .input(1)),
            (500, .input(2)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.recordedOutput)
    }
    
    func testTrampolinesImmediatelyScheduledTasks() {
        
        let subject = TestScheduler(initialClock: 0)
        
        let publisher1 = PassthroughSubject<Int, Never>()
        
        let results = subject.createTestableSubscriber(Int.self, Never.self)
        
        subject.schedule(after: 100) { publisher1.subscribe(results) }
        subject.schedule(after: 200) {
            subject.schedule {
                subject.schedule {
                    publisher1.send(2)
                }
                publisher1.send(1)
            }
            publisher1.send(0)
        }
        
        subject.resume()
        
        let expected: TestSequence<Int, Never> = [
            (100, .subscription),
            (200, .input(0)),
            (200, .input(1)),
            (200, .input(2)),
        ]
        
        XCTAssertEqual(expected, results.recordedOutput)
    }
    
    func testSchedulesAndCancelsRepeatingTask() {
        
        let subject = TestScheduler(initialClock: 0)
        let publisher1 = PassthroughSubject<VirtualTime, Never>()
        let results = subject.createTestableSubscriber(VirtualTime.self, Never.self)
        
        subject.schedule(after: 100, { publisher1.subscribe(results) })
        let cancellable = subject.schedule(
            after: 200,
            interval: 2,
            tolerance: subject.minimumTolerance,
            options: nil,
            { publisher1.send(subject.now) }
        )
        subject.schedule(after: 210, { cancellable.cancel() })
        subject.resume()
        
        let expected: TestSequence<VirtualTime, Never> = [
            (100, .subscription),
            (200, .input(200)),
            (202, .input(202)),
            (204, .input(204)),
            (206, .input(206)),
            (208, .input(208)),
            (210, .input(210)),
        ]
        
        XCTAssertEqual(expected, results.recordedOutput)
    }
    
    func testIgnoresTasksAfterMaxClock() {
        let subject = TestScheduler(initialClock: 0, maxClock: 500)
        let publisher1 = PassthroughSubject<VirtualTime, Never>()
        let results = subject.createTestableSubscriber(VirtualTime.self, Never.self)
        
        subject.schedule(after: 100, { publisher1.subscribe(results) })
        let cancellable = subject.schedule(
            after: 0,
            interval: 100,
            tolerance: subject.minimumTolerance,
            options: nil,
            { publisher1.send(subject.now) }
        )
        subject.resume()
        cancellable.cancel()
        
        let expected: TestSequence<VirtualTime, Never> = [
            (100, .subscription),
            (100, .input(100)),
            (200, .input(200)),
            (300, .input(300)),
            (400, .input(400)),
            (500, .input(500)),
        ]
        
        XCTAssertEqual(expected, results.recordedOutput)
    }
    
    func testRemovesTaskCancelledWithinOwnAction() {
        let subject = TestScheduler(initialClock: 0, maxClock: 500)
        let publisher1 = PassthroughSubject<VirtualTime, Never>()
        let results = subject.createTestableSubscriber(VirtualTime.self, Never.self)
        var cancellables = Set<AnyCancellable>()
        
        subject.schedule(after: 100, { publisher1.subscribe(results) })
        subject.schedule(
                after: 200,
                interval: 100,
                tolerance: subject.minimumTolerance,
                options: nil) {
                    publisher1.send(subject.now)
                    cancellables.removeAll()
                }
            .store(in: &cancellables)
        subject.resume()
        
        let expected: TestSequence<VirtualTime, Never> = [
            (100, .subscription),
            (200, .input(200))
        ]
        
        XCTAssertEqual(expected, results.recordedOutput)
    }

    static var allTests = [
        ("testSchedulerTasksSortSensibly", testSchedulerTasksSortSensibly),
        ("testSchedulerInvokesTask", testSchedulerInvokesBasicTask),
        ("testSchedulerInvokesTasksInTimeOrder", testSchedulerInvokesTasksInTimeOrder),
        ("testSchedulerInvokesDeferredTask", testSchedulerInvokesDeferredTask),
        ("testSchedulerInvokesDeferredTaskScheduledForPastImmediately", testSchedulerInvokesDeferredTaskScheduledForPastImmediately),
        ("testSchedulerRemovesCancelledTasks", testSchedulerRemovesCancelledTasks),
        ("testSchedulerQueues", testSchedulerQueues),
        ("testFiresEventsScheduledBeforeStartCalled", testFiresEventsScheduledBeforeStartCalled),
        ("testTrampolinesImmediatelyScheduledTasks", testTrampolinesImmediatelyScheduledTasks),
        ("testSchedulesRepeatingTask", testSchedulesAndCancelsRepeatingTask),
        ("testIgnoresTasksAfterMaxClock", testIgnoresTasksAfterMaxClock),
        ("testRemovesTaskCancelledWithinOwnAction", testRemovesTaskCancelledWithinOwnAction),
        ("testSchedulerAdvancesToTasksTime", testSchedulerAdvancesToTasksTime),
        ("testSchedulerAdvancesToTasksByTimeInterval", testSchedulerAdvancesToTasksByTimeInterval)
    ]
}

#endif
