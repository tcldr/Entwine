//
//  File.swift
//  
//
//  Created by Tristan Celder on 21/06/2019.
//

import Combine

extension Publishers {
    
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
