
import Combine
import XCTest

@testable import TestScheduler

final class TestSchedulerTests: XCTestCase {
    
    func testSchedulerTasksSortSensibly() {
        
        // this should order by time, then id
        
        let t0 = TestSchedulerTask(id: 0, time: 200, action: {})
        let t1 = TestSchedulerTask(id: 1, time: 200, action: {})
        let t2 = TestSchedulerTask(id: 2, time: 300, action: {})
        let t3 = TestSchedulerTask(id: 3, time: 300, action: {})
        let t4 = TestSchedulerTask(id: 4, time: 400, action: {})
        let t5 = TestSchedulerTask(id: 5, time: 400, action: {})
        let t6 = TestSchedulerTask(id: 6, time: 100, action: {})
        let t7 = TestSchedulerTask(id: 7, time: 100, action: {})
        
        let unsorted = [t0, t1, t2, t3, t4, t5, t6, t7,]
        let sorted = [t6, t7, t0, t1, t2, t3, t4, t5,]
        
        XCTAssertEqual(unsorted.sorted(), sorted)
    }
    
    func testSchedulerInvokesBasicTask() {
        
        let scheduler = TestScheduler(initialClock: 0)
        var scheduledTaskDidRun = false
        scheduler.schedule {
            scheduledTaskDidRun = true
        }
        
        scheduler.resume()
        
        XCTAssert(scheduledTaskDidRun)
    }
    
    func testSchedulerInvokesTasksInTimeOrder() {
        let scheduler = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        
        scheduler.schedule(after: 300) {
            times.append(scheduler.now)
        }
        scheduler.schedule(after: 200) {
            times.append(scheduler.now)
        }
        scheduler.schedule(after: 100) {
            times.append(scheduler.now)
        }
        
        scheduler.resume()
        
        XCTAssertEqual(times, [100, 200, 300,])
    }
    
    func testSchedulerInvokesDeferredTask() {
        let scheduler = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        
        scheduler.schedule(after: 100) {
            times.append(scheduler.now)
            scheduler.schedule(after: scheduler.now + 100) {
                times.append(scheduler.now)
            }
        }
        
        scheduler.resume()
        
        XCTAssertEqual(times, [100, 200,])
    }
    
    func testSchedulerInvokesDeferredTaskScheduledForPastImmediately() {
        let scheduler = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        
        scheduler.schedule(after: 100) {
            times.append(scheduler.now)
            scheduler.schedule(after: scheduler.now - 100) {
                times.append(scheduler.now)
            }
        }
        
        scheduler.resume()
        
        XCTAssertEqual(times, [100, 100,])
    }
    
    func testSchedulerRemovesCancelledTasks() {
        let scheduler = TestScheduler(initialClock: 0)
        var times = [VirtualTime]()
        
        
        scheduler.schedule(after: 100) {
            times.append(scheduler.now)
        }
        let cancellable = scheduler.schedule(after: 200, interval: 0) {
            times.append(scheduler.now)
        }
        scheduler.schedule(after: 300) {
            times.append(scheduler.now)
        }
        
        cancellable.cancel()
        scheduler.resume()
        
        XCTAssertEqual(times, [100, 300,])
    }
    
    func testSchedulerQueues() {
        
        let scheduler = TestScheduler(initialClock: 0)
        
        let publisher1 = PassthroughSubject<Int, Never>()
        let publisher2 = PassthroughSubject<Int, Never>()
        
        let subject = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { publisher1.subscribe(subject) }
        scheduler.schedule(after: 110) { publisher1.send(0) }
        scheduler.schedule(after: 200) { publisher2.subscribe(subject) }
        scheduler.schedule(after: 210) { publisher2.send(1) }
        scheduler.schedule(after: 310) { publisher1.send(2) }
        
        scheduler.resume()
        
        let expected: [TestableSubscriberEvent<Int, Never>] = [
            .init(100, .subscribe),
            .init(110, .input(0)),
            .init(310, .input(2)),
        ]
        
        XCTAssertEqual(expected, subject.events)
    }
    
    func testFiresEventsScheduledBeforeStartCalled() {
        
        let scheduler = TestScheduler(initialClock: 0)
        
        let publisher1 = PassthroughSubject<Int, Never>()
        
        scheduler.schedule(after: 300) { publisher1.send(0) }
        scheduler.schedule(after: 400) { publisher1.send(1) }
        scheduler.schedule(after: 500) { publisher1.send(2) }
        
        let testableSubscriber = scheduler.start { publisher1 }
        
        let expected: [TestableSubscriberEvent<Int, Never>] = [
            .init(200, .subscribe),
            .init(300, .input(0)),
            .init(400, .input(1)),
            .init(500, .input(2)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }

    static var allTests = [
        ("testSchedulerTasksSortSensibly", testSchedulerTasksSortSensibly),
        ("testSchedulerInvokesTask", testSchedulerInvokesBasicTask),
        ("testSchedulerInvokesTasksInTimeOrder", testSchedulerInvokesTasksInTimeOrder),
        ("testSchedulerInvokesDeferredTask", testSchedulerInvokesDeferredTask),
        ("testSchedulerInvokesDeferredTaskScheduledForPastImmediately", testSchedulerInvokesDeferredTaskScheduledForPastImmediately),
        ("testSchedulerRemovesCancelledTasks", testSchedulerRemovesCancelledTasks),
    ]
}
