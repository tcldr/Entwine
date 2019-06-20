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

final class DematerializeTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }

    // MARK: - Tests
    
    func testDematerializesEmpty() {
        
        let materializedElements: [Signal<Int, Never>] = [
            .subscribe,
            .completion(.finished)
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        let expected1: [TestableSubscriberEvent<Int, Never>] = [
            .init(200, .subscribe),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
    
    func testDematerializesError() {
        
        enum MaterializedError: Error { case error }
        
        let materializedElements: [Signal<Int, MaterializedError>] = [
            .subscribe,
            .completion(.failure(.error))
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        let expected1: [TestableSubscriberEvent<Int, MaterializedError>] = [
            .init(200, .subscribe),
            .init(200, .completion(.failure(.error))),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
    
    func testDematerializesJust1() {
        
        let materializedElements: [Signal<Int, Never>] = [
            .subscribe,
            .input(1),
            .completion(.finished)
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        let expected1: [TestableSubscriberEvent<Int, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(1)),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
}
