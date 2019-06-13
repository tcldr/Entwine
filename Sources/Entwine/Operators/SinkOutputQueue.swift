
import Combine

// MARK: - SinkOutputQueue definition

class SinkOutputQueue<Input, Failure: Error> {
    
    let sink: AnySubscriber<Input, Failure>
    
    private var queuedItems = [Input]()
    private var capacity = Subscribers.Demand.none
    
    init<S: Subscriber>(sink: S) where S.Input == Input, S.Failure == Failure {
        self.sink = sink.eraseToAnySubscriber()
    }
    
    func enqueueItem(_ item: Input) {
        queuedItems.append(item)
        dispatchPendingItems()
    }
    
    func enqueueItems(_ items: [Input]) {
        queuedItems.append(contentsOf: items)
        dispatchPendingItems()
    }
    
    func request(_ demand: Subscribers.Demand) {
        capacity += demand
        dispatchPendingItems()
    }
    
    private func dispatchPendingItems() {
        
        let nextBatchRange = nextDispatchRange()
        var dispatchBatch = queuedItems[nextBatchRange]
        queuedItems.removeSubrange(nextBatchRange)
        
        while !dispatchBatch.isEmpty {
            capacity += (sink.receive(dispatchBatch.removeFirst()) - 1)
        }
    }
    
    private func nextDispatchRange() -> Range<Int> {
        
        let remainingItems = queuedItems.count
        let dispatchGroupCount = (capacity.max ?? remainingItems)
        let firstIndex = queuedItems.startIndex
        let endIndex = firstIndex + min(dispatchGroupCount, remainingItems)
        return firstIndex..<endIndex
    }
}
