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
    
    /// Converts a materialized publisher of `Signal`s into the represented sequence. Fails on a malformed
    /// source sequence.
    ///
    /// Use this operator to convert a stream of `Signal` values from an upstream publisher into
    /// its materially represented publisher type. Malformed sequences will fail with a
    /// `DematerializationError`.
    ///
    /// For each element:
    /// - `.subscription` elements are ignored
    /// - `.input(_)` elements are unwrapped and forwarded to the subscriber
    /// - `.completion(_)` elements are forwarded within the `DematerializationError` wrapper
    ///
    /// If the integrity of the upstream sequence can be guaranteed, applying the `assertNoDematerializationFailure()`
    /// operator to this publisher will force unwrap any errors and produce a publisher with a `Failure`
    /// type that matches the materially represented original sequence.
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
    
    // MARK: - Subscription
    
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
            self.sink?.cancelUpstreamSubscription()
            self.sink = nil
        }
    }
    
    // MARK: - Sink
    
    fileprivate class DematerializeSink<Upstream: Publisher, Downstream: Subscriber>: Subscriber
        where
            Upstream.Output: SignalConvertible,
            Downstream.Input == AnyPublisher<Upstream.Output.Input, DematerializationError<Upstream.Output.Failure>>,
            Downstream.Failure == DematerializationError<Upstream.Output.Failure>
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        enum Status { case pending, active(PassthroughSubject<Input.Input, Downstream.Failure>), complete }
        
        var queue: SinkQueue<Downstream>
        var upstreamSubscription: Subscription?
        var status = Status.pending
        
        init(upstream: Upstream, downstream: Downstream) {
            self.queue = SinkQueue(sink: downstream)
            upstream.subscribe(self)
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
                guard case .pending = status else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    return .none
                }
                let subject = PassthroughSubject<Input.Input, Downstream.Failure>()
                status = .active(subject)
                return queue.enqueue(subject.eraseToAnyPublisher())
                
            case .input(let dematerializedInput):
                guard case .active(let subject) = status else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    return .none
                }
                subject.send(dematerializedInput)
                // re-imburse the sender as we're not queueing an
                // additional element on the outer stream, only
                // sending an element on the inner-stream
                return .max(1)
                
            case .completion(let dematerializedCompletion):
                guard case .active(let subject) = status else {
                    queue.expediteCompletion(.failure(.outOfSequence))
                    return .none
                }
                status = .complete
                subject.send(completion: wrapSourceCompletion(dematerializedCompletion))
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

// MARK: - Operators

extension Publisher where Output: SignalConvertible, Failure == Never {
    
    private func dematerializedValuesPublisherSequence() -> Publishers.Dematerialize<Self> {
        Publishers.Dematerialize(upstream: self)
    }
    
    /// Converts a materialized upstream publisher of `Signal`s into the represented sequence. Fails on
    /// a malformed source sequence.
    ///
    /// Use this operator to convert a stream of `Signal` values from an upstream publisher into
    /// its materially represented publisher type. Malformed sequences will fail with a
    /// `DematerializationError`.
    ///
    /// For each element:
    /// - `.subscription` elements are ignored
    /// - `.input(_)` elements are unwrapped and forwarded to the subscriber
    /// - `.completion(_)` elements are forwarded within the `DematerializationError` wrapper
    ///
    /// If the integrity of the upstream sequence can be guaranteed, use the `assertNoDematerializationFailure()`
    /// operator immediately following this one to force unwrap any errors and produce a publisher with a `Failure`
    /// type that matches the materially represented original sequence.
    ///
    /// - Returns: A publisher that materializes an upstream publisher of `Signal`s into the represented
    /// sequence.
    public func dematerialize() -> Publishers.FlatMap<AnyPublisher<Self.Output.Input, DematerializationError<Self.Output.Failure>>, Publishers.Dematerialize<Self>> {
        Publishers.Dematerialize(upstream: self).flatMap { $0 }
    }
}

extension Publisher where Failure: DematerializationErrorConvertible {
    
    /// Force unwraps the errors of a dematerialized publisher to return a publisher that matches that of
    /// the materially represented original sequence
    ///
    /// When using the `dematerialize()` operator the publisher returned has a `Failure` type of
    /// `DematerializationError` to account for the possibility of a malformed `Signal` sequence.
    ///
    /// If the integrity of the upstream sequence can be guaranteed, use this operator to force unwrap the
    /// errors to produce a publisher with a `Failure` type that matches the materially represented original
    /// sequence.
    ///
    /// - Returns: A publisher with a `Failure` type that matches that of the materially represented original
    /// sequence
    func assertNoDematerializationFailure() -> Publishers.MapError<Self, Failure.SourceError> {
        return mapError { error -> Failure.SourceError in
            guard case .sourceError(let e) = error.dematerializationError else {
                preconditionFailure("Unhandled dematerialization error: \(error)")
            }
            return e
        }
    }
}

// MARK: - Errors

/// Represents an error for a dematerialized sequence
///
/// Consumers of publishers with a `Failure` of this type can opt-in to force unwrapping
/// the error using the `assertNoDematerializationFailure()` operator
public enum DematerializationError<SourceError: Error>: Error {
    /// Sequencing error during dematerialization. e.g. an `.input` arriving after a `.completion`
    case outOfSequence
    /// A wrapped error of the represented material sequence
    case sourceError(SourceError)
}

extension DematerializationError: Equatable where SourceError: Equatable {}

/// A type which can be converted into a `DematerializationError`
public protocol DematerializationErrorConvertible {
    
    associatedtype SourceError: Error
    
    /// The type represented as a `DematerializationError`
    var dematerializationError: DematerializationError<SourceError> { get }
}

extension DematerializationError: DematerializationErrorConvertible {
    public var dematerializationError: DematerializationError<SourceError> { self }
}
