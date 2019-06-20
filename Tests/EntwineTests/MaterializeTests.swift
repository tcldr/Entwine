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
    
    func testMaterializesEmpty() {
        
        let results1 = scheduler.start { Publishers.Empty<Int, Never>().materialize() }
        
        let expected1: [TestableSubscriberEvent<Signal<Int, Never>, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.subscribe)),
            .init(200, .input(.completion(.finished))),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
    
    func testMaterializesError() {
        
        enum MaterializedError: Error { case error }
        
        let results1 = scheduler.start { Publishers.Fail<Int, MaterializedError>(error: .error).materialize() }
        
        let expected1: [TestableSubscriberEvent<Signal<Int, MaterializedError>, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.subscribe)),
            .init(200, .input(.completion(.failure(.error)))),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
    }
    
    func testMaterializesJust1() {
        
        let results1 = scheduler.start { Publishers.Just<Int>(1).materialize() }
        
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
