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
    
    // MARK: - Publisher
    
    /// Wraps all the elements as well as the subscription and completion events of an upstream publisher
    /// into a stream of `Signal` elements
    public struct Materialize<Upstream: Publisher>: Publisher {
        
        public typealias Output = Signal<Upstream.Output, Upstream.Failure>
        public typealias Failure = Never
        
        private let upstream: Upstream
        
        init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: MaterializeSubscription(upstream: upstream, downstream: subscriber))
        }
    }
    
    // MARK: - Subscription
    
    // Owned by the downstream subscriber
    fileprivate class MaterializeSubscription<Upstream: Publisher, Downstream: Subscriber>: Subscription
        where Never == Downstream.Failure, Signal<Upstream.Output, Upstream.Failure> == Downstream.Input
    {
        var sink: MaterializeSink<Upstream, Downstream>?
        
        init(upstream: Upstream, downstream: Downstream) {
            self.sink = MaterializeSink(upstream: upstream, downstream: downstream)
        }
        
        // Subscription Methods
        
        // Called by the downstream subscriber to signal
        // additional elements can be sent
        func request(_ demand: Subscribers.Demand) {
            sink?.signalDemand(demand)
        }
        
        // Called by the downstream subscriber to end the
        // subscription and clean up any resources.
        // Shouldn't be a blocking call, but it is legal
        // for a few more elements to arrive after this is
        // called.
        func cancel() {
            self.sink = nil
        }
    }
    
    // MARK: - Sink
    
    fileprivate class MaterializeSink<Upstream: Publisher, Downstream: Subscriber>: Subscriber
         where Never == Downstream.Failure, Signal<Upstream.Output, Upstream.Failure> == Downstream.Input
    {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        var queue: SinkQueue<Downstream>
        var upstreamSubscription: Subscription?
        
        init(upstream: Upstream, downstream: Downstream) {
            self.queue = SinkQueue(sink: downstream)
            upstream.subscribe(self)
        }
        
        deinit {
            cancelUpstreamSubscription()
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // that the subscription has begun
        func receive(subscription: Subscription) {
            self.upstreamSubscription = subscription
            let demand = queue.enqueue(.subscription)
            guard demand > .none else { return }
            subscription.request(demand)
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // an element has arrived, signals to the upstream publisher
        // how many more elements can be sent
        func receive(_ input: Input) -> Subscribers.Demand {
            return queue.enqueue(.input(input))
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // that the sequence has terminated
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            _ = queue.enqueue(.completion(completion))
            _ = queue.enqueue(completion: .finished)
            cancelUpstreamSubscription()
        }
        
        // Indirectly called by the downstream subscriber via its subscription
        // to signal that more items can be sent downstream
        func signalDemand(_ demand: Subscribers.Demand) {
            let spareDemand = queue.requestDemand(demand)
            guard spareDemand > .none else { return }
            upstreamSubscription?.request(spareDemand)
        }
        
        func cancelUpstreamSubscription() {
            upstreamSubscription?.cancel()
            upstreamSubscription = nil
        }
    }
}

// MARK: - Operator

public extension Publisher {
    
    /// Wraps each element from the upstream publisher, as well as its subscription and completion events,
    /// into `Signal` values.
    ///
    /// - Returns: A publisher that wraps each element from the upstream publisher, as well as its
    /// subscription and completion events, into `Signal` values.
    func materialize() -> Publishers.Materialize<Self> {
        Publishers.Materialize(upstream: self)
    }
}
