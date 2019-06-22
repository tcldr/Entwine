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

final class FactoryTests: XCTestCase {
    
    func testCreatesNever() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { _ in AnyCancellable { } }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (900, .completion(.finished)),
        ])
    }
    
    func testCreatesEmpty() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            dispatcher.forward(completion: .finished)
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .completion(.finished)),
        ])
    }
    
    func testCreatesJust() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            dispatcher.forward(0)
            dispatcher.forward(completion: .finished)
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .input(0)),
            (200, .completion(.finished)),
        ])
    }
    
    func testFiresAsynchronousEvents() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let sut = Publishers.Factory<Int, Never> { dispatcher in
            
            testScheduler.schedule(after: testScheduler.now +  10) { dispatcher.forward(0) }
            testScheduler.schedule(after: testScheduler.now +  20) { dispatcher.forward(1) }
            testScheduler.schedule(after: testScheduler.now +  30) { dispatcher.forward(2) }
            testScheduler.schedule(after: testScheduler.now + 100) { dispatcher.forward(completion: .finished) }
            
            return AnyCancellable { }
        }
        
        let testableSubscriber = testScheduler.start { sut }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (210, .input(0)),
            (220, .input(1)),
            (230, .input(2)),
            (300, .completion(.finished))
        ])
    }
}
