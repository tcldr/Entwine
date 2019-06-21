
import Combine

// MARK: - SinkQueue definition

class SinkQueue<Sink: Subscriber> {
    
    private var sink: Sink?
    private var buffer = LinkedListQueue<Sink.Input>()
    
    private var demandRequested = Subscribers.Demand.none
    private var demandProcessed = Subscribers.Demand.none
    private var demandForwarded = Subscribers.Demand.none
    private var demandQueued: Subscribers.Demand { .max(buffer.count) }
    
    private var completion: Subscribers.Completion<Sink.Failure>?
    
    init(sink: Sink) {
        self.sink = sink
    }
    
    deinit {
        expediteCompletion(.finished)
    }
    
    func requestDemand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        demandRequested += demand
        return processDemand()
    }
    
    func enqueue(_ input: Sink.Input) -> Subscribers.Demand {
        buffer.enqueue(input)
        return processDemand()
    }
    
    func enqueue(completion: Subscribers.Completion<Sink.Failure>) -> Subscribers.Demand {
        self.completion = completion
        return processDemand()
    }
    
    func expediteCompletion(_ completion: Subscribers.Completion<Sink.Failure>) {
        guard let sink = sink else { return }
        self.sink = nil
        self.buffer = .empty
        sink.receive(completion: completion)
    }
    
    // Processes as much demand as requested, returns spare capacity that
    // can be forwarded to upstream subscriber/s
    func processDemand() -> Subscribers.Demand {
        while demandProcessed < demandRequested, let next = buffer.next() {
            demandProcessed += 1
            demandRequested += sink?.receive(next) ?? .none
        }
        if let completion = completion, demandQueued < 1 {
            expediteCompletion(completion)
            return .none
        }
        let spareDemand = max(.none, demandRequested - demandProcessed - demandQueued - demandForwarded)
        demandForwarded += spareDemand
        return spareDemand
    }
}
