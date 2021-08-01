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

#if canImport(Combine)

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class TestablePublisherTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testColdObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            (  0, .input(.init())),
            (200, .input(.init())),
            (400, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.recordedOutput, [
            (200, .subscription),
            (200, .input(.init())),
            (400, .input(.init())),
            (600, .input(.init())),
        ])
    }
    
    func testHotObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createAbsoluteTestablePublisher([
            (  0, .input(.init())),
            (200, .input(.init())),
            (400, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.recordedOutput, [
            (200, .subscription),
            (200, .input(.init())),
            (400, .input(.init())),
        ])
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testColdObservableProducesExpectedValues),
        ("testHotObservableProducesExpectedValues", testHotObservableProducesExpectedValues),
    ]
}

#endif
