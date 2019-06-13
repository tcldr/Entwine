//
//  File.swift
//  
//
//  Created by Tristan Celder on 07/06/2019.
//

import Combine

extension Publishers {
    
    public struct MyMap<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        let upstream: Upstream
        let transform: (Upstream.Output) -> Output
        
        init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            upstream.subscribe(MyMapSink(downstream: subscriber, transform: transform))
        }
    }
    
    fileprivate class MyMapSink<Downstream: Subscriber, Input>: Subscriber {
        
        typealias Failure = Downstream.Failure
        
        let downstream: Downstream
        let transform: (Input) -> Downstream.Input
        
        init(downstream: Downstream, transform: @escaping (Input) -> Downstream.Input) {
            self.downstream = downstream
            self.transform = transform
        }
        
        func receive(subscription: Subscription) {
            return downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(transform(input))
        }
        
        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            return downstream.receive(completion: completion)
        }
    }
}

public extension Publisher {
    
    func myMap<T>(_ transform: @escaping (Output) -> T) -> Publishers.MyMap<Self, T> {
        Publishers.MyMap<Self, T>(upstream: self, transform: transform)
    }
}
