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

extension Publishers {
    
    /// Creates a simple `Publisher` inline from a provided closure
    ///
    /// This `Publisher`can be used to turn any arbitrary source of values (such as a timer or a user authorization
    /// request) into a new `Publisher` sequence.
    ///
    /// From within the scope of the closure passed into the initializer, it is possible to call the methods of the
    /// `Dispatcher` object – which is passed in as a parameter – to send values down stream.
    ///
    /// - Warning: Developers should be aware that a `Dispatcher` has an unbounded buffer that stores values
    /// yet to be requested by the downstream `Subscriber`.
    ///
    /// When creating a `Publisher` from a source with an unbounded rate of production that cannot be influenced,
    /// developers should consider following this operator with a `Publishers.Buffer` operator to prevent a
    /// strain on resources
    public struct Factory<Output, Failure: Error>: Publisher {
        
        let subscription: (Dispatcher<Output, Failure>) -> AnyCancellable
        
        public init(_ subscription: @escaping (Dispatcher<Output, Failure>) -> AnyCancellable) {
            self.subscription = subscription
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: FactorySubscription(sink: subscriber, subscription: subscription))
        }
    }
}

fileprivate class FactorySubscription<Sink: Subscriber>: Subscription {
    
    var subscription: ((Dispatcher<Sink.Input, Sink.Failure>) -> AnyCancellable)?
    var dispatcher: FactoryDispatcher<Sink.Input, Sink.Failure, Sink>?
    var cancellable: AnyCancellable?
    
    init(sink: Sink, subscription: @escaping (Dispatcher<Sink.Input, Sink.Failure>) -> AnyCancellable) {
        self.subscription = subscription
        self.dispatcher = FactoryDispatcher(sink: sink)
    }
    
    func request(_ demand: Subscribers.Demand) {
        _ = dispatcher?.queue.requestDemand(demand)
        startUpstreamSubscriptionIfNeeded()
    }
    
    func startUpstreamSubscriptionIfNeeded() {
        guard let subscription = subscription, let dispatcher = dispatcher else { return }
        self.subscription = nil
        cancellable = subscription(dispatcher)
    }
    
    func cancel() {
        cancellable = nil
        dispatcher = nil
    }
}

// MARK: - Public facing Dispatcher defintion

public class Dispatcher<Input, Failure: Error> {
    
    public func forward(_ input: Input) {
        fatalError("Abstract class. Override in subclass.")
    }
    
    public func forward(completion: Subscribers.Completion<Failure>) {
        fatalError("Abstract class. Override in subclass.")
    }
    
    public func forwardImmediately(completion: Subscribers.Completion<Failure>) {
        fatalError("Abstract class. Override in subclass.")
    }
}

// MARK: - Internal Dispatcher defintion

class FactoryDispatcher<Input, Failure, Sink: Subscriber>: Dispatcher<Input, Failure>
    where Input == Sink.Input, Failure == Sink.Failure
{
    
    let queue: SinkQueue<Sink>
    
    init(sink: Sink) {
        self.queue = SinkQueue(sink: sink)
    }
    
    public override func forward(_ input: Input) {
        _ = queue.enqueue(input)
    }
    
    public override func forward(completion: Subscribers.Completion<Failure>) {
        _ = queue.enqueue(completion: completion)
    }
    
    public override func forwardImmediately(completion: Subscribers.Completion<Failure>) {
        queue.expediteCompletion(completion)
    }
}
