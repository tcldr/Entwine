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

import Combine
import Entwine
import Foundation

// MARK: - Behavior value definition

public enum TestablePublisherBehavior { case hot, cold }

// MARK: - Publisher definition

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

fileprivate final class TestablePublisherSubscription<Sink: Subscriber>: Subscription {
    
    private let linkedList = LinkedList<Int>.empty
    private let queue: SinkQueue<Sink>
    private var cancellables = [AnyCancellable]()
    
    init(sink: Sink, testScheduler: TestScheduler, behavior: TestablePublisherBehavior, testSequence: TestSequence<Sink.Input, Sink.Failure>) {
        
        self.queue = SinkQueue(sink: sink)
        
        testSequence.events.forEach { recordedEvent in
            
            guard behavior == .cold || testScheduler.now <= recordedEvent.time else { return }
            let due = behavior == .cold ? testScheduler.now + recordedEvent.time : recordedEvent.time
            
            switch recordedEvent.signal {
            case .subscription:
                assertionFailure("Illegal input. `.subscription` events will be ignored. \(recordedEvent)")
                break
            case .input(let value):
                let cancellable = testScheduler.schedule(after: due, interval: 0) { [unowned self] in
                    _ = self.queue.enqueue(value)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            case .completion(let completion):
                let cancellable = testScheduler.schedule(after: due, interval: 0) { [unowned self] in
                    self.queue.expediteCompletion(completion)
                }
                cancellables.append(AnyCancellable { cancellable.cancel() })
            }
        }
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    func request(_ demand: Subscribers.Demand) {
        _ = queue.requestDemand(demand)
    }
    
    func cancel() {
        queue.expediteCompletion(.finished)
    }
}
