//
//  File.swift
//  
//
//  Created by Tristan Celder on 21/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class FactoryTests: XCTestCase {
    
    func testCreatesNever() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { _ in AnyCancellable { } }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.events, [
            .subscription(200),
            .completion(900, .finished)
        ])
    }
    
    func testCreatesEmpty() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            dispatcher.forward(completion: .finished)
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.events, [
            .subscription(200),
            .completion(200, .finished)
        ])
    }
    
    func testCreatesJust() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            dispatcher.forward(0)
            dispatcher.forward(completion: .finished)
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.events, [
            .subscription(200),
            .input(200, 0),
            .completion(200, .finished)
        ])
    }
    
    func testFiresAsynchronousEvents() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            
            testScheduler.schedule(after: testScheduler.now +  10) { dispatcher.forward(0) }
            testScheduler.schedule(after: testScheduler.now +  20) { dispatcher.forward(1) }
            testScheduler.schedule(after: testScheduler.now +  30) { dispatcher.forward(2) }
            testScheduler.schedule(after: testScheduler.now + 100) { dispatcher.forward(completion: .finished) }
            
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.events, [
            .subscription(200),
            .input(210, 0),
            .input(220, 1),
            .input(230, 2),
            .completion(300, .finished)
        ])
    }
}
