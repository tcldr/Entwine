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
import os.log

extension Publishers {
    
    // MARK: - Publisher configuration
    
    /// Configuration values for the `Publishers.Signpost` operator.
    ///
    /// Pass `Publishers.SignpostConfiguration.Marker` values to the initializer to define how signposts for
    /// each event should be labelled:
    /// - A nil marker value will disable signposts for that event
    /// - A `.default` marker value will use the event name as the event label
    /// - A `.named(_:)` marker value will use the passed string as the event label
    public struct SignpostConfiguration {
        
        public struct Marker {
            
            /// A marker that specifies a signpost should use the default label for an event
            public static let `default` = Marker()
            
            /// A marker that specifies a signpost should use the passed name as a label for an event
            /// - Parameter name: The name the signpost should be labelled with
            public static func named(_ name: StaticString) -> Marker {
                Marker(name)
            }
            
            let name: StaticString?
            
            init (_ name: StaticString? = nil) {
                self.name = name
            }
        }
        
        /// Configuration values for the `Publishers.Signpost` operator.
        ///
        /// The default value specifies signposts should be grouped into the `com.github.tcldr.Entwine.Signpost`
        /// subsystem using the `.pointsOfInterest` category (displayed in most Xcode Intruments templates
        /// by default under the 'Points of Interest' instrument).
        ///
        /// Use a `Publishers.SignpostConfiguration.Marker` value to define how signposts for each event should
        /// be labelled:
        /// - A nil marker value will disable signposts for that event
        /// - A `.default` marker value will use the event name as the event label
        /// - A `.named(_:)` marker value will use the passed string as the event label
        ///
        /// - Parameters:
        ///     - log: The OSLog parameters to be used to mark signposts
        ///     - receiveSubscriptionMarker: A marker value to identify subscription events. A `default` value yields an event labelled `subscription`
        ///     - receiveMarker: A marker value to identify sequence output events. A `default` value yields an event labelled `receive`
        ///     - receiveCompletionMarker: A marker value to identify sequence completion events. A `default` value yields an event labelled `receiveCompletion`
        ///     - requestMarker: A marker value to identify demand request events. A `default` value yields an event labelled `request`
        ///     - cancelMarker: A marker value to identify cancellation events. A `default` value yields an event labelled `cancel`
        public init(
            log: OSLog = OSLog(subsystem: "com.github.tcldr.Entwine.Signpost", category: .pointsOfInterest),
            receiveSubscriptionMarker: Marker? = nil,
            receiveMarker: Marker? = nil,
            receiveCompletionMarker: Marker? = nil,
            requestMarker: Marker? = nil,
            cancelMarker: Marker? = nil
        ) {
            self.log = log
            self.receiveSubscriptionMarker = receiveSubscriptionMarker
            self.receiveMarker = receiveMarker
            self.receiveCompletionMarker = receiveCompletionMarker
            self.requestMarker = requestMarker
            self.cancelMarker = cancelMarker
        }
        
        public var log: OSLog
        public var receiveSubscriptionMarker: Marker?
        public var receiveMarker: Marker?
        public var receiveCompletionMarker: Marker?
        public var requestMarker: Marker?
        public var cancelMarker: Marker?
    }
    
    // MARK: - Publisher
    
    public struct Signpost<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let configuration: SignpostConfiguration
        
        init(upstream: Upstream, configuration: SignpostConfiguration) {
            self.upstream = upstream
            self.configuration = configuration
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            upstream.subscribe(SignpostSink(downstream: subscriber, configuration: configuration))
        }
    }
    
    // MARK: - Sink
    
    fileprivate class SignpostSink<Downstream: Subscriber>: Subscriber {
        
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure
        
        private var downstream: Downstream
        private let configuration: SignpostConfiguration
        
        init(downstream: Downstream, configuration: SignpostConfiguration) {
            self.downstream = downstream
            self.configuration = configuration
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: SignpostSubscription(wrappedSubscription: subscription, configuration: configuration))
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            guard let marker = configuration.receiveMarker else {
                return downstream.receive(input)
            }
            let signpostID = OSSignpostID(log: configuration.log)
            os_signpost(.begin, log: configuration.log, name: marker.name ?? "receive", signpostID: signpostID)
            defer { os_signpost(.end, log: configuration.log, name: marker.name ?? "receive", signpostID: signpostID) }
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard let marker = configuration.receiveCompletionMarker else {
                downstream.receive(completion: completion)
                return
            }
            let signpostID = OSSignpostID(log: configuration.log)
            os_signpost(.begin, log: configuration.log, name: marker.name ?? "receiveCompletion", signpostID: signpostID)
            downstream.receive(completion: completion)
            os_signpost(.end, log: configuration.log, name: marker.name ?? "receiveCompletion", signpostID: signpostID)
        }
    }
    
    // MARK: - Subscription
    
    fileprivate class SignpostSubscription: Subscription {
        
        private let wrappedSubscription: Subscription
        private let configuration: SignpostConfiguration
        
        init(wrappedSubscription: Subscription, configuration: SignpostConfiguration) {
            self.wrappedSubscription = wrappedSubscription
            self.configuration = configuration
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard let marker = configuration.requestMarker else {
                wrappedSubscription.request(demand)
                return
            }
            let signpostID = OSSignpostID(log: configuration.log)
            os_signpost(.begin, log: configuration.log, name: marker.name ?? "request", signpostID: signpostID, "%{public}@", String(describing: demand))
            wrappedSubscription.request(demand)
            os_signpost(.end, log: configuration.log, name: marker.name ?? "request", signpostID: signpostID)
        }
        
        func cancel() {
            guard let marker = configuration.cancelMarker else {
                wrappedSubscription.cancel()
                return
            }
            let signpostID = OSSignpostID(log: configuration.log)
            os_signpost(.begin, log: configuration.log, name: marker.name ?? "cancel", signpostID: signpostID)
            wrappedSubscription.cancel()
            os_signpost(.end, log: configuration.log, name: marker.name ?? "cancel", signpostID: signpostID)
        }
    }
}

// MARK: - Operator

public extension Publisher {
    
    /// Marks points of interest for your publisher events as time intervals for debugging performance in Instruments.
    ///
    /// - Parameter configuration: A configuration value specifying which events to mark as points of interest.
    /// The default value specifies signposts should be grouped into the `com.github.tcldr.Entwine.Signpost`
    /// subsystem using the `.pointsOfInterest` category (displayed in most Xcode Intruments templates
    /// by default under the 'Points of Interest' instrument) . See `Publishers.SignpostConfiguration`
    /// initializer for detailed options.
    /// - Returns: A publisher that marks points of interest when specified publisher events occur
    func signpost(configuration: Publishers.SignpostConfiguration = .init(receiveMarker: .default)) -> Publishers.Signpost<Self> {
        Publishers.Signpost(upstream: self, configuration: configuration)
    }
}

