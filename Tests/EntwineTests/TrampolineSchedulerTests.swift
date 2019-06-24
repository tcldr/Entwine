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

final class TrampolineSchedulerTests: XCTestCase {
    
    func testSchedulerTrampolinesActions() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        let subject = TrampolineScheduler.shared
        
        let publisher1 = PassthroughSubject<String, Never>()
        
        let results = testScheduler.createTestableSubscriber(String.self, Never.self)
        
        let action3 = {
            publisher1.send("3a")
            publisher1.send("3b")
        }
        
        let action2 = {
            publisher1.send("2a")
            subject.schedule(action3)
            publisher1.send("2b")
        }
        
        let action1 = {
            publisher1.send("1a")
            subject.schedule(action2)
            publisher1.send("1b")
        }
        
        testScheduler.schedule(after: 100) { publisher1.subscribe(results) }
        testScheduler.schedule(after: 200) { subject.schedule(action1) }
        
        testScheduler.resume()
        
        let expected: TestSequence<String, Never> = [
            (100, .subscription),
            (200, .input("1a")),
            (200, .input("1b")),
            (200, .input("2a")),
            (200, .input("2b")),
            (200, .input("3a")),
            (200, .input("3b")),
        ]
        
        XCTAssertEqual(expected, results.sequence)
    }
    
    func testSchedulerPerformsAsFIFOQueue() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        let subject = TrampolineScheduler.shared
        
        let publisher1 = PassthroughSubject<String, Never>()
        
        let results = testScheduler.createTestableSubscriber(String.self, Never.self)
        
        let action = {
            publisher1.send("outerAction: A")
            subject.schedule { publisher1.send("innerAction1") }
            subject.schedule { publisher1.send("innerAction2") }
            publisher1.send("outerAction: B")
        }
        
        testScheduler.schedule(after: 100) { publisher1.subscribe(results) }
        testScheduler.schedule(after: 200) { subject.schedule(action) }
        
        testScheduler.resume()
        
        let expected: TestSequence<String, Never> = [
            (100, .subscription),
            (200, .input("outerAction: A")),
            (200, .input("outerAction: B")),
            (200, .input("innerAction1")),
            (200, .input("innerAction2")),
        ]
        
        XCTAssertEqual(expected, results.sequence)
    }
}
