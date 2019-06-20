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
            upstream.subscribe(sink)
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
        
        let upstream: Upstream
        
        var queue: SinkQueue<Downstream>
        var upstreamSubscription: Subscription?
        
        init(upstream: Upstream, downstream: Downstream) {
            self.queue = SinkQueue(sink: downstream)
            self.upstream = upstream
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
            upstreamSubscription?.request(spareDemand)
        }
        
        func cancelUpstreamSubscription() {
            upstreamSubscription?.cancel()
            upstreamSubscription = nil
        }
    }
    
    fileprivate class SinkQueue<Sink: Subscriber> {
        
        var sink: Sink?
        var buffer = LinkedListQueue<Sink.Input>()
        
        var demandRequested = Subscribers.Demand.none
        var demandProcessed = Subscribers.Demand.none
        var demandQueued: Subscribers.Demand { .max(buffer.count) }
        
        var completion: Subscribers.Completion<Sink.Failure>?
        
        init(sink: Sink) {
            self.sink = sink
        }
        
        func requestDemand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
            demandRequested += demand
            return processDemand()
        }
        
        func enqueue(_ input: Sink.Input) -> Subscribers.Demand {
            buffer.enqueue(input)
            return processDemand()
        }
        
        func enqueue(completion: Subscribers.Completion<Sink.Failure>) -> Subscribers.Demand {
            self.completion = completion
            return processDemand()
        }
        
        func expediteCompletion(_ completion: Subscribers.Completion<Sink.Failure>) {
            guard let sink = sink else { return }
            self.sink = nil
            sink.receive(completion: completion)
        }
        
        // Processes as much demand as requested, returns spare capacity that
        // can be forwarded to upstream subscriber/s
        func processDemand() -> Subscribers.Demand {
            while demandProcessed < demandRequested, let next = buffer.next() {
                demandProcessed += 1
                demandRequested += sink?.receive(next) ?? .none
            }
            guard let completion = completion, demandQueued < 1 else {
                let spareDemand = (demandRequested - demandProcessed - demandQueued)
                return max(.none, spareDemand)
            }
            expediteCompletion(completion)
            return .none
        }
    }
}

public extension Publisher {
    
    func materialize() -> Publishers.Materialize<Self> {
        Publishers.Materialize(upstream: self)
    }
}
