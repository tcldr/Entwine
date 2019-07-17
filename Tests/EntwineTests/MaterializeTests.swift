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

final class MaterializeTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }

    // MARK: - Tests
    
    func testMaterializesEmpty() {
        
        let results1 = scheduler.start { Empty<Int, Never>().materialize() }
        
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
        
        let results1 = scheduler.start { Fail<Int, MaterializedError>(error: .error).materialize() }
        
        let expected1: TestSequence<Signal<Int, MaterializedError>, Never> = [
            (200, .subscription),
            (200, .input(.subscription)),
            (200, .input(.completion(.failure(.error)))),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
    }
    
    func testMaterializesJust1() {
        
        let results1 = scheduler.start { Just<Int>(1).materialize() }
        
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
