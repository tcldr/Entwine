//
//  File.swift
//  
//
//  Created by Tristan Celder on 12/06/2019.
//

import Combine

extension Publishers {
    
    public struct Replay<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let replayBuffer: ReplayBuffer<Upstream>
        
        init(upstream: Upstream, maxBufferSize: Int) {
            self.upstream = upstream
            self.replayBuffer = ReplayBuffer(upstream, maxBufferSize: maxBufferSize)
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            
        }
    }
    
    fileprivate class ReplayBuffer<Upstream: Publisher> {
        
        private var cancellable: Cancellable?
        private (set) var values = [Upstream.Output]()
        
        init(_ publisher: Upstream, maxBufferSize: Int) {
            cancellable = publisher.sink { [unowned self] in
                self.values.append($0)
                self.values.removeFirst(self.values.count - maxBufferSize)
            }
        }
    }
    
    fileprivate class MyReplaySink<Downstream: Subscriber, Input>: Subscriber {
        
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
    
    func replay<T>(maxBufferSize: Int) -> Publishers.Replay<Self, T> {
        Publishers.Replay<Self, T>(upstream: self, maxBufferSize: maxBufferSize)
    }
}

