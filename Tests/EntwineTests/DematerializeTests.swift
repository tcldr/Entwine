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
            .subscription,
            .completion(.finished)
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        XCTAssertEqual(results1.sequence, [
            (200, .subscription),
            (200, .completion(.finished)),
        ])
    }
    
    func testDematerializesError() {
        
        enum MaterializedError: Error { case error }
        
        let materializedElements: [Signal<Int, MaterializedError>] = [
            .subscription,
            .completion(.failure(.error))
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        XCTAssertEqual(results1.sequence, [
            (200, .subscription),
            (200, .completion(.failure(.error))),
        ])
    }
    
    func testDematerializesJust1() {
        
        let materializedElements: [Signal<Int, Never>] = [
            .subscription,
            .input(1),
            .completion(.finished)
        ]
        
        let results1 = scheduler.start {
            Publishers.Sequence(sequence: materializedElements)
                .dematerialize()
                .assertNoDematerializationFailure()
        }
        
        XCTAssertEqual(results1.sequence, [
            (200, .subscription),
            (200, .input(1)),
            (200, .completion(.finished)),
        ])
    }
}
