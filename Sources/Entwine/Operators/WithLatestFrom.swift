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

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publishers {
    
    /// A publisher that combines the latest value from another publisher with each value from an upstream publisher
    public struct WithLatestFrom<Upstream: Publisher, Other: Publisher, Output>: Publisher where Upstream.Failure == Other.Failure {
        
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let other: Other
        private let transform: (Upstream.Output, Other.Output) -> Output
        
        public init(upstream: Upstream, other: Other, transform: @escaping (Upstream.Output, Other.Output) -> Output) {
            self.upstream = upstream
            self.other = other
            self.transform = transform
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            let otherSink = WithLatestFromOtherSink(publisher: other)
            let upstreamSink = WithLatestFromSink(upstream: upstream, downstream: subscriber, otherSink: otherSink, transform: transform)
            subscriber.receive(subscription: WithLatestFromSubscription(sink: upstreamSink))
        }
    }
    
    // MARK: - Subscription
    
    fileprivate class WithLatestFromSubscription<Upstream: Publisher, Other: Publisher, Downstream: Subscriber>: Subscription
        where Upstream.Failure == Other.Failure, Upstream.Failure == Downstream.Failure
    {
        
        var sink: WithLatestFromSink<Upstream, Other, Downstream>?
        
        init(sink: WithLatestFromSink<Upstream, Other, Downstream>) {
            self.sink = sink
        }
        
        func request(_ demand: Subscribers.Demand) {
            sink?.signalDemand(demand)
        }
        
        func cancel() {
            self.sink?.terminateSubscription()
            self.sink = nil
        }
    }
    
    // MARK: - Main Sink
    
    fileprivate class WithLatestFromSink<Upstream: Publisher, Other: Publisher, Downstream: Subscriber>: Subscriber
        where Upstream.Failure == Other.Failure, Upstream.Failure == Downstream.Failure
    {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        var queue: SinkQueue<Downstream>
        var upstreamSubscription: Subscription?
        
        let otherSink: WithLatestFromOtherSink<Other>
        let transform: (Upstream.Output, Other.Output) -> Downstream.Input
        
        init(upstream: Upstream, downstream: Downstream, otherSink: WithLatestFromOtherSink<Other>, transform: @escaping (Input, Other.Output) -> Downstream.Input) {
            self.queue = SinkQueue(sink: downstream)
            self.otherSink = otherSink
            self.transform = transform
            
            upstream.subscribe(self)
        }
        
        func receive(subscription: Subscription) {
            self.upstreamSubscription = subscription
            otherSink.subscribe()
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            guard let otherInput = otherSink.lastInput else {
                // we ignore results from the `Upstream` publisher until
                // we have received an item from the `Other` publisher.
                //
                // As we are ignoring this item, we need to signal to the
                // upstream publisher that they may reclaim the budget for
                // the dropped item by returning a Subscribers.Demand of 1.
                return .max(1)
            }
            return queue.enqueue(transform(input, otherInput))
        }
        
        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            terminateSubscription()
            _ = queue.enqueue(completion: completion)
        }
        
        func signalDemand(_ demand: Subscribers.Demand) {
            let spareDemand = queue.requestDemand(demand)
            guard spareDemand > .none else { return }
            upstreamSubscription?.request(spareDemand)
        }
        
        func terminateSubscription() {
            otherSink.terminateSubscription()
            upstreamSubscription?.cancel()
            upstreamSubscription = nil
        }
    }
    
    // MARK: - Other Sink
    
    fileprivate class WithLatestFromOtherSink<P: Publisher>: Subscriber {
        
        typealias Input = P.Output
        typealias Failure = P.Failure
        
        private let publisher: AnyPublisher<P.Output, P.Failure>
        private (set) var lastInput: Input?
        private var subscription: Subscription?
        
        init(publisher: P) {
            self.publisher = publisher.eraseToAnyPublisher()
        }
        
        func subscribe() {
            publisher.subscribe(self)
        }
        
        func receive(subscription: Subscription) {
            self.subscription = subscription
            subscription.request(.unlimited)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lastInput = input
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) { }
        
        func terminateSubscription() {
            subscription?.cancel()
            subscription = nil
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publisher {
    
    /// Subscribes to an additional publisher and invokes a closure upon receiving output from this
    /// publisher.
    ///
    /// - Parameter other: Another publisher to combibe with this one
    /// - Parameter transform: A closure that receives each value produced by this
    /// publisher and the latest value from another publisher and returns a new value to publish
    /// - Returns: A publisher that combines the latest value from another publisher with each
    /// value from this publisher
    func withLatest<T, P: Publisher>(from other: P, transform: @escaping (Output, P.Output) -> T) -> Publishers.WithLatestFrom<Self, P, T> where P.Failure == Failure {
        Publishers.WithLatestFrom(upstream: self, other: other, transform: transform)
    }
    
    /// Subscribes to an additional publisher and produces its latest value each time this publisher
    /// produces a value.
    ///
    /// - Parameter other: Another publisher to gather latest values from
    /// - Returns: A publisher that produces the latest value from another publisher each time
    /// this publisher produces an element
    func withLatest<P: Publisher>(from other: P) -> Publishers.WithLatestFrom<Self, P, P.Output> where P.Failure == Failure {
        withLatest(from: other, transform: { _, b in b })
    }
}

#endif
