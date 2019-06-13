//
//  File.swift
//  
//
//  Created by Tristan Celder on 09/06/2019.
//

import Combine

extension Publishers {
    
    public struct WithLatestFrom<Upstream: Publisher, Other: Publisher, Output>: Publisher where Upstream.Failure == Other.Failure {
        
        public typealias Failure = Upstream.Failure
        
        let upstream: Upstream
        let other: Other
        let transform: (Upstream.Output, Other.Output) -> Output
        
        init(upstream: Upstream, other: Other, transform: @escaping (Upstream.Output, Other.Output) -> Output) {
            self.upstream = upstream
            self.other = other
            self.transform = transform
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            
            let otherSink = WithLatestFromOtherSink(publisher: other)
            let sink = WithLatestFromSink<Upstream, Other, S>(downstream: subscriber, otherSink: otherSink, transform: transform)
            
            upstream.subscribe(sink)
        }
    }
    
    fileprivate class WithLatestFromSink<Upstream: Publisher, Other: Publisher, Downstream: Subscriber>: Subscriber where Upstream.Failure == Other.Failure, Upstream.Failure == Downstream.Failure {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        let downstream: Downstream
        let otherSink: WithLatestFromOtherSink<Other>
        let transform: (Upstream.Output, Other.Output) -> Downstream.Input
        
        init(downstream: Downstream, otherSink: WithLatestFromOtherSink<Other>, transform: @escaping (Input, Other.Output) -> Downstream.Input) {
            self.downstream = downstream
            self.otherSink = otherSink
            self.transform = transform
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
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
            
            return downstream.receive(transform(input, otherInput))
        }
        
        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            otherSink.terminateSubscription()
            downstream.receive(completion: completion)
        }
    }
    
    fileprivate class WithLatestFromOtherSink<P: Publisher>: Subscriber {
        
        typealias Input = P.Output
        typealias Failure = P.Failure
        
        private (set) var lastInput: Input?
        private var subscription: Subscription?
        
        init(publisher: P) {
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
        
        func receive(completion: Subscribers.Completion<Failure>) {
            subscription = nil
        }
        
        func terminateSubscription() {
            subscription?.cancel()
        }
    }
}

public extension Publisher {
    
    func withLatest<T, P: Publisher>(from other: P, transform: @escaping (Output, P.Output) -> T) -> Publishers.WithLatestFrom<Self, P, T> where P.Failure == Failure {
        Publishers.WithLatestFrom(upstream: self, other: other, transform: transform)
    }
    
    func withLatest<P: Publisher>(from other: P) -> Publishers.WithLatestFrom<Self, P, P.Output> where P.Failure == Failure {
        withLatest(from: other, transform: { _, b in b })
    }
}
