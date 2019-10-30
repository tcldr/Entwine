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

final class ReferenceCountedTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }
    
    // MARK: - Tests

    func testAutoConnectsAndPassesThroughInitialValue() {
        
        let passthrough = PassthroughSubject<Int, Never>()
        let subject = passthrough.prepend(-1).share()

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { passthrough.send(0) }
        scheduler.schedule(after: 210) { passthrough.send(1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (100, .subscription),
            (100, .input(-1)),
            (200, .input( 0)),
            (210, .input( 1)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }
    
    func testPassesThroughInitialValueToFirstSubscriberOnly() {
        
        let passthrough = PassthroughSubject<Int, Never>()
        let subject = passthrough.prepend(-1).share()

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.subscribe(results1) }
        scheduler.schedule(after: 110) { subject.subscribe(results2) }
        scheduler.schedule(after: 200) { passthrough.send(0) }
        scheduler.schedule(after: 210) { passthrough.send(1) }

        scheduler.resume()
        
        let expected2: TestSequence<Int, Never> = [
            (110, .subscription),
            (200, .input( 0)),
            (210, .input( 1)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
    }
    
    func testResetsWhenReferenceCountReachesZero() {
        
        let passthrough = PassthroughSubject<Int, Never>()
        let subject = passthrough.prepend(-1).share()

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results3 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.subscribe(results1) }
        scheduler.schedule(after: 110) { subject.subscribe(results2) }
        scheduler.schedule(after: 200) { passthrough.send(0) }
        scheduler.schedule(after: 210) { passthrough.send(1) }
        scheduler.schedule(after: 300) { results1.cancel() }
        scheduler.schedule(after: 310) { results2.cancel() }
        scheduler.schedule(after: 400) { subject.subscribe(results3) }
        scheduler.schedule(after: 500) { passthrough.send(0) }
        scheduler.schedule(after: 510) { passthrough.send(1) }

        scheduler.resume()
        
        let expected3: TestSequence<Int, Never> = [
            (400, .subscription),
            (400, .input(-1)),
            (500, .input( 0)),
            (510, .input( 1)),
        ]
        
        XCTAssertEqual(expected3, results3.recordedOutput)
    }
    
    func testMulticastCreateSubjectCalledWhenSubscriberCountGoesFromZeroToOne() {
        
        var cancellables = Set<AnyCancellable>()
        let factory: () -> PassthroughSubject<Int, Never> = { Swift.print("createSubject()"); return PassthroughSubject() }
        let sut = Just(1)
        sut.multicast(factory).autoconnect().sink { print("A:\($0)") }.store(in: &cancellables)
        cancellables = Set<AnyCancellable>()
        sut.multicast(factory).autoconnect().sink { print("B:\($0)") }.store(in: &cancellables)
    }
}
