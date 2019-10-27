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

// MARK: - Publisher

extension Publishers {

    public final class ReferenceCounted<Upstream: Publisher, SubjectType: Subject>: Publisher
        where Upstream.Output == SubjectType.Output, Upstream.Failure == SubjectType.Failure
    {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let createSubject: () -> SubjectType
        private weak var sharedUpstreamReference: Publishers.Autoconnect<Publishers.Multicast<Upstream, SubjectType>>?
        
        init(upstream: Upstream, createSubject: @escaping () -> SubjectType) {
            self.upstream = upstream
            self.createSubject = createSubject
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            let sharedUpstream = sharedUpstreamPublisher()
            sharedUpstream.subscribe(ReferenceCountedSink(upstream: sharedUpstream, downstream: subscriber))
        }
        
        func sharedUpstreamPublisher() -> Publishers.Autoconnect<Publishers.Multicast<Upstream, SubjectType>> {
            guard let shared = sharedUpstreamReference else {
                let shared = upstream.multicast(createSubject).autoconnect()
                self.sharedUpstreamReference = shared
                return shared
            }
            return shared
        }
    }

    // MARK: - Sink

    fileprivate final class ReferenceCountedSink<Upstream: Publisher, Downstream: Subscriber>: Subscriber
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure
        
        private let upstream: Upstream
        private let downstream: Downstream
        
        init(upstream: Upstream, downstream: Downstream) {
            self.upstream = upstream
            self.downstream = downstream
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: ReferenceCountedSubscription(wrappedSubscription: subscription, sink: self))
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
    }
    
    fileprivate final class ReferenceCountedSubscription<Sink: Subscriber>: Subscription {
        
        let wrappedSubscription: Subscription
        var sink: Sink?
        
        init(wrappedSubscription: Subscription, sink: Sink) {
            self.wrappedSubscription = wrappedSubscription
            self.sink = sink
        }
        
        func request(_ demand: Subscribers.Demand) {
            wrappedSubscription.request(demand)
        }
        
        func cancel() {
            wrappedSubscription.cancel()
            sink = nil
        }
    }
}

// MARK: - Operator

extension Publishers.Multicast {
    
    /// Automates the process of connecting to a connectable publisher.
    ///
    /// - Returns: A publisher which automatically connects to its upstream connectable publisher.
    func referenceCounted() -> Publishers.ReferenceCounted<Upstream, SubjectType> {
        .init(upstream: upstream, createSubject: createSubject)
    }
}
