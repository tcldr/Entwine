//
//  File.swift
//  
//
//  Created by Tristan Celder on 09/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class CombineOperatorsTests: XCTestCase {
    
    func testMyMap() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Int, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 0, 1),
            .init(time: 0, 2),
            .init(time: 0, 3),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.myMap { 2 * $0 }  }
        
        let expected: [TestableSubscriberEvent<Int, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(2)),
            .init(200, .input(4)),
            .init(200, .input(6)),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }

    static var allTests = [
        ("testMyMap", testMyMap),
    ]
}
