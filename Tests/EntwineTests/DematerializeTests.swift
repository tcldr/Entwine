//
//  Entwine
//  https://github.com/tcldr/Entwine
//
//  Copyright © 2019 Tristan Celder. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
        
        XCTAssertEqual(results1.recordedOutput, [
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
        
        XCTAssertEqual(results1.recordedOutput, [
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
        
        XCTAssertEqual(results1.recordedOutput, [
            (200, .subscription),
            (200, .input(1)),
            (200, .completion(.finished)),
        ])
    }
}
