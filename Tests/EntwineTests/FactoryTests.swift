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
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (900, .completion(.finished)),
        ])
    }
    
    func testCreatesEmpty() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            dispatcher.forward(completion: .finished)
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .completion(.finished)),
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
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .input(0)),
            (200, .completion(.finished)),
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
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (210, .input(0)),
            (220, .input(1)),
            (230, .input(2)),
            (300, .completion(.finished))
        ])
    }
}
