//
//  File.swift
//  
//
//  Created by Tristan Celder on 20/06/2019.
//

import Combine

extension Publishers {
    
    public struct Materialize<Upstream: Publisher>: Publisher {
        
        public typealias Output = Signal<Upstream.Output, Upstream.Failure>
        public typealias Failure = Never
        
        private let upstream: Upstream
        
        public init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: MaterializeSubscription(upstream: upstream, downstream: subscriber))
        }
    }
    
    // Owned by the downstream subscriber
    fileprivate class MaterializeSubscription<Upstream: Publisher, Downstream: Subscriber>: Subscription
        where Never == Downstream.Failure, Signal<Upstream.Output, Upstream.Failure> == Downstream.Input
    {
        var sink: MaterializeSink<Upstream, Downstream>?
        
        init(upstream: Upstream, downstream: Downstream) {
            let sink = MaterializeSink(upstream: upstream, downstream: downstream)
            self.sink = sink
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
            queue.expediteCompletion(.finished)
            cancelUpstreamSubscription()
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // that the subscription has begun
        func receive(subscription: Subscription) {
            self.upstreamSubscription = subscription
            let demand = queue.enqueue(.subscribe)
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

public extension Publisher {
    
    func materialize() -> Publishers.Materialize<Self> {
        Publishers.Materialize(upstream: self)
    }
}
