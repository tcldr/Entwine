//
//  File.swift
//  
//
//  Created by Tristan Celder on 20/06/2019.
//

import Combine

public enum DematerializationError<SourceError: Error>: Error {
    case outOfSequence
    case sourceError(SourceError)
}

extension DematerializationError: Equatable where SourceError: Equatable {}

extension Publishers {
    
    public struct Dematerialize<Upstream: Publisher>: Publisher where Upstream.Output: SignalConvertible {
        
        public typealias Failure = DematerializationError<Upstream.Output.Failure>
        public typealias Output = AnyPublisher<Upstream.Output.Input, Failure>
        
        private let upstream: Upstream
        
        init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: DematerializeSubscription(upstream: upstream, downstream: subscriber))
        }
    }
    
    fileprivate class DematerializeSubscription<Upstream: Publisher, Downstream: Subscriber>: Subscription
         where
            Upstream.Output: SignalConvertible,
            Downstream.Input == AnyPublisher<Upstream.Output.Input, DematerializationError<Upstream.Output.Failure>>,
            Downstream.Failure == DematerializationError<Upstream.Output.Failure>
    {
        var sink: DematerializeSink<Upstream, Downstream>?
        
        init(upstream: Upstream, downstream: Downstream) {
            let sink = DematerializeSink(upstream: upstream, downstream: downstream)
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
    
    fileprivate class DematerializeSink<Upstream: Publisher, Downstream: Subscriber>: Subscriber
        where
            Upstream.Output: SignalConvertible,
            Downstream.Input == AnyPublisher<Upstream.Output.Input, DematerializationError<Upstream.Output.Failure>>,
            Downstream.Failure == DematerializationError<Upstream.Output.Failure>
    {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        var queue: SinkQueue<Downstream>
        var upstreamSubscription: Subscription?
        var currentMaterializationSubject: PassthroughSubject<Input.Input, Downstream.Failure>?
        
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
            let demand = queue.processDemand()
            guard demand > .none else { return }
            subscription.request(demand)
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // an element has arrived, signals to the upstream publisher
        // how many more elements can be sent
        func receive(_ input: Input) -> Subscribers.Demand {
            
            switch input.signal {
            case .subscription:
                guard currentMaterializationSubject == nil else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    cancelUpstreamSubscription()
                    return .none
                }
                currentMaterializationSubject = .init()
                return queue.enqueue(currentMaterializationSubject!.eraseToAnyPublisher())
                
            case .input(let dematerializedInput):
                guard let subject = currentMaterializationSubject else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    cancelUpstreamSubscription()
                    return .none
                }
                subject.send(dematerializedInput)
                // re-imburse the sender as we're not queueing an
                // additional element on the outer stream, only
                // sending an element on the inner-stream
                return .max(1)
                
            case .completion(let dematerializedCompletion):
                guard let subject = currentMaterializationSubject else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    cancelUpstreamSubscription()
                    return .none
                }
                currentMaterializationSubject = nil
                subject.send(completion: wrapSourceCompletion(dematerializedCompletion))
                // re-imburse the sender as we're not queueing an
                // additional element on the outer stream, only
                // sending an element on the inner-stream
                return .none
            }
        }
        
        func wrapSourceCompletion<E: Error>(_ completion: Subscribers.Completion<E>) -> Subscribers.Completion<DematerializationError<E>> {
            guard case .failure(let error) = completion else { return .finished }
            return .failure(.sourceError(error))
        }
        
        // Called by the upstream publisher (or its agent) to signal
        // that the sequence has terminated
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
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

public extension Publisher where Output: SignalConvertible, Failure == Never {
    
    func dematerializedPublisherSequence() -> Publishers.Dematerialize<Self> {
        Publishers.Dematerialize(upstream: self)
    }
    
    func dematerialize() -> Publishers.FlatMap<AnyPublisher<Self.Output.Input, DematerializationError<Self.Output.Failure>>, Publishers.First<Publishers.Dematerialize<Self>>> {
        return dematerializedPublisherSequence().first().flatMap { $0 }
    }
}

public extension Publisher where Failure: DematerializationErrorConvertible {
    
    func assertNoDematerializationFailure() -> Publishers.MapError<Self, Self.Failure.SourceError> {
        return mapError { error -> Failure.SourceError in
            guard case .sourceError(let e) = error.dematerializationError else {
                preconditionFailure("Unhandled dematerialization error: \(error.dematerializationError)")
            }
            return e
        }
    }
}

public protocol DematerializationErrorConvertible {
    
    associatedtype SourceError: Error
    
    var dematerializationError: DematerializationError<SourceError> { get }
}

extension DematerializationError: DematerializationErrorConvertible {
    
    public var dematerializationError: DematerializationError<SourceError> {
        return self
    }
}
