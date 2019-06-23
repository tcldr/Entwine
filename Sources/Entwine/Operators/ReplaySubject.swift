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

/// A subject that maintains a buffer of its latest values for replay to new subscribers and passes
/// through subsequent elements and completion
///
/// The subject passes through elements and completion states unchanged and in addition
/// replays the latest elements to any new subscribers. Use this subject when you want subscribers
/// to receive the most recent previous elements in addition to all future elements.
public final class ReplaySubject<Output, Failure: Error> {
    
    typealias Sink = AnySubscriber<Output, Failure>
    
    private enum Status { case active, completed }
    
    private var status = Status.active
    private var subscriptions = [ReplaySubjectSubscription<Sink>]()
    private var subscriberIdentifiers = Set<CombineIdentifier>()
    
    private var buffer = [Output]()
    private var replayValues: ReplaySubjectValueBuffer<Output>
    
    var subscriptionCount: Int {
        return subscriptions.count
    }
    
    /// - Parameter maxBufferSize: The number of elements that should be buffered for
    /// replay to new subscribers
    /// - Returns: A subject that maintains a buffer of its recent values for replay to new subscribers
    ///  and passes through subsequent values and completion
    public init(maxBufferSize: Int) {
        self.replayValues = .init(maxBufferSize: maxBufferSize)
    }
}

extension ReplaySubject: Publisher {
    
    public func receive<S : Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        
        guard status != .completed, !subscriberIdentifiers.contains(subscriber.combineIdentifier) else {
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: .finished)
            return
        }
        
        let subscriberIdentifier = subscriber.combineIdentifier
        let subscription = ReplaySubjectSubscription(sink: AnySubscriber(subscriber), replayedInputs: replayValues.buffer)
        
        // we use seperate collections for identifiers and subscriptions
        // to improve performance of identifier lookups and to keep the
        // order in which subscribers are signalled to be in the order that
        // they intially subscribed.
        
        subscriberIdentifiers.insert(subscriberIdentifier)
        subscriptions.append(subscription)
        
        subscription.cleanupHandler = { [weak self] in
            if let index = self?.subscriptions.firstIndex(where: { subscriberIdentifier == $0.subscriberIdentifier }) {
                self?.subscriberIdentifiers.remove(subscriberIdentifier)
                self?.subscriptions.remove(at: index)
            }
        }
        subscriber.receive(subscription: subscription)
    }
}

extension ReplaySubject: Subject {
    
    public func send(_ value: Output) {
        guard status == .active else { return }
        replayValues.addValueToBuffer(value)
        subscriptions.forEach { subscription in
            subscription.forwardValueToSink(value)
        }
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        guard status == .active else { return }
        self.status = .completed
        subscriptions.forEach { subscription in
            subscription.forwardCompletionToSink(completion)
        }
        subscriptions.removeAll()
    }
}

fileprivate final class ReplaySubjectSubscription<Sink: Subscriber>: Subscription {
    
    private let queue: SinkQueue<Sink>
    
    var cleanupHandler: (() -> Void)?
    let subscriberIdentifier: CombineIdentifier
    
    init<ReplayedInputs: Sequence>(sink: Sink, replayedInputs: ReplayedInputs) where ReplayedInputs.Element == Sink.Input {
        self.queue = SinkQueue(sink: sink)
        self.subscriberIdentifier = sink.combineIdentifier
        replayedInputs.forEach { _ = queue.enqueue($0) }
    }
    
    func forwardValueToSink(_ value: Sink.Input) {
        _ = queue.enqueue(value)
    }
    
    func forwardCompletionToSink(_ completion: Subscribers.Completion<Sink.Failure>) {
        queue.expediteCompletion(completion)
        cleanup()
    }
    
    func request(_ demand: Subscribers.Demand) {
        _ = queue.requestDemand(demand)
    }
    
    func cancel() {
        queue.expediteCompletion(.finished)
        cleanup()
    }
    
    func cleanup() {
        cleanupHandler?()
        cleanupHandler = nil
    }
}

extension ReplaySubject {
    
    public static func createUnbounded() -> ReplaySubject<Output, Failure> {
        return .init(maxBufferSize: .max)
    }
    
    public static func create(bufferSize: Int) -> ReplaySubject<Output, Failure> {
        return .init(maxBufferSize: bufferSize)
    }
}

fileprivate struct ReplaySubjectValueBuffer<Value> {
    
    let maxBufferSize: Int
    private (set) var buffer = LinkedListQueue<Value>()
    
    init(maxBufferSize: Int) {
        self.maxBufferSize = maxBufferSize
    }
    
    mutating func addValueToBuffer(_ value: Value) {
        buffer.enqueue(value)
        if buffer.count > maxBufferSize {
            _ = buffer.dequeue()
        }
    }
}
