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
        
        let expected1: TestSequence<Signal<Int, Never>, Never> = [
            (200, .subscription),
            (200, .input(.subscription)),
            (200, .input(.completion(.finished))),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
    }
    
    func testMaterializesError() {
        
        enum MaterializedError: Error { case error }
        
        let results1 = scheduler.start { Publishers.Fail<Int, MaterializedError>(error: .error).materialize() }
        
        let expected1: TestSequence<Signal<Int, MaterializedError>, Never> = [
            (200, .subscription),
            (200, .input(.subscription)),
            (200, .input(.completion(.failure(.error)))),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
    }
    
    func testMaterializesJust1() {
        
        let results1 = scheduler.start { Publishers.Just<Int>(1).materialize() }
        
        let expected1: TestSequence<Signal<Int, Never>, Never> = [
            (200, .subscription),
            (200, .input(.subscription)),
            (200, .input(.input(1))),
            (200, .input(.completion(.finished))),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
    }
}
