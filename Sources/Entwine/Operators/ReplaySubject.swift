//
//  File.swift
//  
//
//  Created by Tristan Celder on 10/06/2019.
//

import Combine

public final class ReplaySubject<Output, Failure: Error> {
    
    enum Status { case active, completed }
    
    private var status = Status.active
    private var subscriptions = [ReplaySubjectSubscription<Output, Failure>]()
    private var subscriberIdentifiers = Set<CombineIdentifier>()
    
    private var buffer = [Output]()
    private var replayValues: ReplaySubjectValueBuffer<Output>
    
    var subscriptionCount: Int {
        return subscriptions.count
    }
    
    init(maxBufferSize: Int) {
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
        Swift.print("VALUE: \(value)")
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

fileprivate final class ReplaySubjectSubscription<Input, Failure: Error>: Subscription {
    
    private let queue: SinkOutputQueue<Input, Failure>
    
    var cleanupHandler: (() -> Void)?
    let subscriberIdentifier: CombineIdentifier
    
    init<S: Subscriber, ReplayedInputs: Sequence>(sink: S, replayedInputs: ReplayedInputs) where S.Failure == Failure, S.Input == Input, ReplayedInputs.Element == Input {
        self.queue = SinkOutputQueue(sink: sink)
        self.subscriberIdentifier = sink.combineIdentifier
        queue.enqueueItems(replayedInputs)
    }
    
    func forwardValueToSink(_ value: Input) {
        queue.enqueueItem(value)
    }
    
    func forwardCompletionToSink(_ completion: Subscribers.Completion<Failure>) {
        queue.complete(completion)
        cleanupHandler?()
        cleanupHandler = nil
    }
    
    func request(_ demand: Subscribers.Demand) {
        queue.request(demand)
    }
    
    func cancel() {
        forwardCompletionToSink(.finished)
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
