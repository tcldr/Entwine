//
//  File.swift
//  
//
//  Created by Tristan Celder on 15/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class TrampolineSchedulerTests: XCTestCase {
    
    func testSchedulerTrampolinesActions() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        let subject = TrampolineScheduler.shared
        
        let publisher1 = PassthroughSubject<String, Never>()
        
        let results = testScheduler.createTestableSubscriber(String.self, Never.self)
        
        let action3 = {
            publisher1.send("3a")
            publisher1.send("3b")
        }
        
        let action2 = {
            publisher1.send("2a")
            subject.schedule(action3)
            publisher1.send("2b")
        }
        
        let action1 = {
            publisher1.send("1a")
            subject.schedule(action2)
            publisher1.send("1b")
        }
        
        testScheduler.schedule(after: 100) { publisher1.subscribe(results) }
        testScheduler.schedule(after: 200) { subject.schedule(action1) }
        
        testScheduler.resume()
        
        let expected: [TestableSubscriberEvent<String, Never>] = [
            .init(100, .subscribe),
            .init(200, .input("1a")),
            .init(200, .input("1b")),
            .init(200, .input("2a")),
            .init(200, .input("2b")),
            .init(200, .input("3a")),
            .init(200, .input("3b")),
        ]
        
        XCTAssertEqual(expected, results.events)
    }
    
    func testSchedulerPerformsAsFIFOQueue() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        let subject = TrampolineScheduler.shared
        
        let publisher1 = PassthroughSubject<String, Never>()
        
        let results = testScheduler.createTestableSubscriber(String.self, Never.self)
        
        let action = {
            publisher1.send("outerAction: A")
            subject.schedule { publisher1.send("innerAction1") }
            subject.schedule { publisher1.send("innerAction2") }
            publisher1.send("outerAction: B")
        }
        
        testScheduler.schedule(after: 100) { publisher1.subscribe(results) }
        testScheduler.schedule(after: 200) { subject.schedule(action) }
        
        testScheduler.resume()
        
        let expected: [TestableSubscriberEvent<String, Never>] = [
            .init(100, .subscribe),
            .init(200, .input("outerAction: A")),
            .init(200, .input("outerAction: B")),
            .init(200, .input("innerAction1")),
            .init(200, .input("innerAction2")),
        ]
        
        XCTAssertEqual(expected, results.events)
    }
}
