//
//  File.swift
//  
//
//  Created by Tristan Celder on 20/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class MaterializeTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }

    // MARK: - Tests
    
    func testMaterializesColdSequence() {
        
//        let source: TestablePublisher<Int, Never> = scheduler.createTestableHotPublisher([
//            .init(time: 300, 0),
//            .init(time: 400, 1),
//            .init(time: 500, 2),
//        ])
        
        let results1 = scheduler.start { Publishers.Just<Int>(1).materialize() }
        
//        let expected1: [TestableSubscriberEvent<Int, Never>] = [
//            .init(200, .subscribe),
//            .init(200, .input(1)),
//            .init(200, .completion(.finished)),
//        ]
        
        let expected1: [TestableSubscriberEvent<Signal<Int, Never>, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.subscribe)),
            .init(200, .input(.input(1))),
            .init(200, .input(.completion(.finished))),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
}
