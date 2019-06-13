//
//  File.swift
//  
//
//  Created by Tristan Celder on 10/06/2019.
//

import Combine

public final class ReplaySubject<Output, Failure: Error> {
    
    private var subscriptions = [ReplaySubjectSubscription<Output, Failure>]()
    private var subscriberIdentifiers = Set<CombineIdentifier>()
    
    private var buffer = [Output]()
    private var replayValues: ReplaySubjectValueBuffer<Output>
    
    private var isDispatching = false
    
    var subscriptionCount: Int {
        return subscriptions.count
    }
    
    init(maxBufferSize: Int) {
        self.replayValues = .init(maxBufferSize: maxBufferSize)
    }
}

extension ReplaySubject: Publisher {
    
    public func receive<S : Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        
        guard !subscriberIdentifiers.contains(subscriber.combineIdentifier) else {
            subscriber.receive(completion: .finished)
            return
        }
        
        let subscriberIdentifier = subscriber.combineIdentifier
        let subscription = ReplaySubjectSubscription(sink: AnySubscriber(subscriber), replayedInputs: replayValues.buffer)
        
        // we use seperate collections for identifiers and subscriptions
        // to improve performance of identifier lookups and to keep the
        // order in which subscribers are signalled to be the order in that
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
        
        replayValues.addValueToBuffer(value)
        
        assert(!isDispatching)
        isDispatching = true
        subscriptions.forEach { subscription in
            subscription.forwardValueToSink(value)
        }
        isDispatching = false
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        subscriptions.forEach { subscription in
            subscription.forwardCompletionToSink(completion)
        }
        subscriptions.removeAll()
    }
}

fileprivate final class ReplaySubjectSubscription<Input, Failure: Error>: Subscription {
    
    private var queue: SinkOutputQueue<Input, Failure>?
    
    var cleanupHandler: (() -> Void)?
    let subscriberIdentifier: CombineIdentifier
    
    init<S: Subscriber>(sink: S, replayedInputs: [Input]) where S.Input == Input, S.Failure == Failure {
        self.queue = SinkOutputQueue(sink: sink)
        self.queue?.enqueueItems(replayedInputs)
        self.subscriberIdentifier = sink.combineIdentifier
    }
    
    func forwardValueToSink(_ value: Input) {
        queue?.enqueueItem(value)
    }
    
    func forwardCompletionToSink(_ completion: Subscribers.Completion<Failure>) {
        guard let queue = queue else { return }
        self.queue = nil
        queue.sink.receive(completion: .finished)
        cleanupHandler?()
    }
    
    func request(_ demand: Subscribers.Demand) {
        queue?.request(demand)
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
    
    private (set) var buffer = [Value]()
    let maxBufferSize: Int
    
    init(maxBufferSize: Int) {
        self.maxBufferSize = maxBufferSize
    }
    
    mutating func addValueToBuffer(_ value: Value) {
        buffer.append(value)
        if buffer.count > maxBufferSize {
            buffer.removeFirst()
        }
    }
}
