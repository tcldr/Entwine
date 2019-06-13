//
//  File.swift
//  
//
//  Created by Tristan Celder on 12/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class BufferTests: XCTestCase {
    
//    func testBuffersAsExpected() {
//        
//        let scheduler = TestScheduler(initialClock: 0)
//        
//        let passthroughSubject = PassthroughSubject<Int, Never>()
//        let subject = passthroughSubject.buffer(size: 2, prefetch: .byRequest, whenFull: .dropOldest).share().makeConnectable()
//        let cancellable = subject.connect()
//        
//        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
//        
//        scheduler.schedule(after: 200) { passthroughSubject.send(1) }
//        scheduler.schedule(after: 300) { passthroughSubject.send(2) }
//        scheduler.schedule(after: 400) { passthroughSubject.send(3) }
//        scheduler.schedule(after: 500) { subject.subscribe(results1) }
//        scheduler.schedule(after: 600) { passthroughSubject.send(4) }
//        scheduler.schedule(after: 700) { passthroughSubject.send(5) }
////        scheduler.schedule(after: 800) { results1.terminateSubscription() }
//        
//        scheduler.resume()
//        
//        let expected1: [TestableSubscriberEvent<Int, Never>] = [
//            .init(500, .subscribe),
//            .init(500, .input(2)),
//            .init(500, .input(3)),
//            .init(600, .input(4)),
//            .init(700, .input(5)),
////            .init(800, .completion(.finished)),
//        ]
//        
//        XCTAssertEqual(expected1, results1.events)
//        
//        cancellable.cancel()
//    }
//    
//    static var allTests = [
//        ("testBuffersAsExpected", testBuffersAsExpected),
//    ]
}
