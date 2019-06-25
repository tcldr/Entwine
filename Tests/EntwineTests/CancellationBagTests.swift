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

final class CancellationBagTests: XCTestCase {
    
    func testBagCancelsContainedCancellablesOnDeallocation() {
        
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, Never>()
        let subscriber = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        var sut: CancellationBag! = CancellationBag()
        
        subscriber.cancelled(by: sut)
        
        scheduler.schedule(after: 100) { subject.subscribe(subscriber) }
        scheduler.schedule(after: 110) { subject.send(1) }
        scheduler.schedule(after: 120) { subject.send(2) }
        scheduler.schedule(after: 130) { sut = nil }
        scheduler.schedule(after: 140) { subject.send(3) }
        
        scheduler.resume()
        
        XCTAssertEqual(subscriber.sequence, [
            (100, .subscription),
            (110, .input(1)),
            (120, .input(2)),
        ])
    }
    
    func testBagCancelsContainedCancellablesOnExplicitCancel() {
        
        let scheduler = TestScheduler()
        let subject = PassthroughSubject<Int, Never>()
        let subscriber = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        let sut = CancellationBag()
        
        subscriber.cancelled(by: sut)
        
        scheduler.schedule(after: 100) { subject.subscribe(subscriber) }
        scheduler.schedule(after: 110) { subject.send(1) }
        scheduler.schedule(after: 120) { subject.send(2) }
        scheduler.schedule(after: 130) { sut.cancel() }
        scheduler.schedule(after: 140) { subject.send(3) }
        
        scheduler.resume()
        
        XCTAssertEqual(subscriber.sequence, [
            (100, .subscription),
            (110, .input(1)),
            (120, .input(2)),
        ])
    }
}
