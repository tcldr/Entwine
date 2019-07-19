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

// MARK: - SinkQueue definition

class SinkQueue<Sink: Subscriber> {
    
    private var sink: Sink?
    private var buffer = LinkedListQueue<Sink.Input>()
    
    private var demandRequested = Subscribers.Demand.none
    private var demandProcessed = Subscribers.Demand.none
    private var demandForwarded = Subscribers.Demand.none
    
    private var completion: Subscribers.Completion<Sink.Failure>?
    private var isActive: Bool { sink != nil && completion == nil }
    private var shouldBuffer: Bool { demandRequested < .unlimited }
    
    init(sink: Sink) {
        self.sink = sink
    }
    
    func requestDemand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
        demandRequested += demand
        return processDemand()
    }
    
    func enqueue(_ input: Sink.Input) -> Subscribers.Demand {
        guard completion == nil, let sink = sink else {
            assertionFailure("Out of sequence. A completion signal is queued or has already been sent.")
            return .none
        }
        guard shouldBuffer else {
            return sink.receive(input)
        }
        buffer.enqueue(input)
        return processDemand()
    }
    
    func enqueue(completion: Subscribers.Completion<Sink.Failure>) -> Subscribers.Demand {
        guard self.completion == nil, sink != nil else {
            assertionFailure("Out of sequence. A completion signal is queued or has already been sent.")
            return .none
        }
        guard shouldBuffer else {
            expediteCompletion(completion)
            return .none
        }
        self.completion = completion
        return processDemand()
    }
    
    func expediteCompletion(_ completion: Subscribers.Completion<Sink.Failure>) {
        guard let sink = sink else {
            assertionFailure("Out of sequence. A completion signal has already been sent.")
            return
        }
        self.sink = nil
        self.buffer = .empty
        sink.receive(completion: completion)
    }
    
    // Processes as much demand as requested, returns spare capacity that
    // can be forwarded to upstream subscriber/s
    func processDemand() -> Subscribers.Demand {
        guard let sink = sink else { return .none }
        while demandProcessed < demandRequested, let next = buffer.next() {
            demandProcessed += 1
            demandRequested += sink.receive(next)
        }
        if let completion = completion, buffer.count < 1 {
            expediteCompletion(completion)
            return .none
        }
        let forwardableDemand = (demandRequested - demandForwarded)
        demandForwarded += forwardableDemand
        return forwardableDemand
    }
}
