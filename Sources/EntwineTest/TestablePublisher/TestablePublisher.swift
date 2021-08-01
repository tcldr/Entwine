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

import Combine
import Entwine
import Foundation

// MARK: - Behavior value definition

enum TestablePublisherBehavior { case absolute, relative }

// MARK: - Publisher definition

/// A `Publisher` that produces the elements provided in a `TestSequence`.
///
/// Initializable using the factory methods on `TestScheduler`
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct TestablePublisher<Output, Failure: Error>: Publisher {
    
    private let testScheduler: TestScheduler
    private let testSequence: TestSequence<Output, Failure>
    private let behavior: TestablePublisherBehavior
    
    init(testScheduler: TestScheduler, behavior: TestablePublisherBehavior, testSequence: TestSequence<Output, Failure>) {
        self.testScheduler = testScheduler
        self.testSequence = testSequence
        self.behavior = behavior
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
        subscriber.receive(subscription:
            TestablePublisherSubscription(
                sink: subscriber, testScheduler: testScheduler, behavior: behavior, testSequence: testSequence))
    }
}

// MARK: - Subscription definition

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate final class TestablePublisherSubscription<Sink: Subscriber>: Subscription {
    
    private let linkedList = LinkedList<Int>.empty
    private var queue: SinkQueue<Sink>?
    private var cancellables = [AnyCancellable]()
    
    init(sink: Sink, testScheduler: TestScheduler, behavior: TestablePublisherBehavior, testSequence: TestSequence<Sink.Input, Sink.Failure>) {
        
        let queue = SinkQueue(sink: sink)
        
        testSequence.forEach { (time, signal) in
            
            guard behavior == .relative || testScheduler.now <= time else { return }
            let due = behavior == .relative ? testScheduler.now + time : time
            
            switch signal {
            case .subscription:
                assertionFailure("Illegal input. A `.subscription` event scheduled at \(time) will be ignored. Only a Subscriber can initiate a Subscription.")
                break
            case .input(let value):
                let cancellable = testScheduler.schedule(after: due, interval: 0) {
                    _ = queue.enqueue(value)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            case .completion(let completion):
                let cancellable = testScheduler.schedule(after: due, interval: 0) {
                    queue.expediteCompletion(completion)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            }
        }
        
        self.queue = queue
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    func request(_ demand: Subscribers.Demand) {
        _ = queue?.requestDemand(demand)
    }
    
    func cancel() {
        queue = nil
    }
}

#endif