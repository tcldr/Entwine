
import Combine
import Foundation

// MARK: - Class definition

/// A scheduler for performing trampolined actions.
///
/// You can only use this scheduler for immediate actions. If you attempt to schedule
/// actions after a specific date, the scheduler produces a fatal error.
public final class TrampolineScheduler {
    
    public static let shared = TrampolineScheduler()
    
    static let localThreadActionQueueKey = "com.github.tcldr.Entwine.TrampolineScheduler.localThreadActionQueueKey"
    
    static var localThreadActionQueue: TrampolineSchedulerQueue {
        guard let queue = Thread.current.threadDictionary.value(forKey: Self.localThreadActionQueueKey) as? TrampolineSchedulerQueue else {
            let newQueue = TrampolineSchedulerQueue()
            Thread.current.threadDictionary.setValue(newQueue, forKey: Self.localThreadActionQueueKey)
            return newQueue
        }
        return queue
    }
}

// MARK: - Scheduler conformance

extension TrampolineScheduler: Scheduler {
    
    public typealias SchedulerTimeType = ImmediateScheduler.SchedulerTimeType
    public typealias SchedulerOptions = ImmediateScheduler.SchedulerOptions
    
    public var now: TrampolineScheduler.SchedulerTimeType {
        ImmediateScheduler.shared.now
    }
    
    public var minimumTolerance: TrampolineScheduler.SchedulerTimeType.Stride {
        ImmediateScheduler.shared.minimumTolerance
    }
    
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        Self.localThreadActionQueue.push(action)
    }
    
    public func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        fatalError("You can only use this scheduler for immediate actions")
    }
    
    public func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        fatalError("You can only use this scheduler for immediate actions")
    }
}


// MARK: - Scheduler Queue

final class TrampolineSchedulerQueue {
    
    typealias Action = () -> Void
    enum Status { case idle, active }
    
    private (set) var queuedActions = LinkedListQueue<Action>()
    private (set) var status = Status.idle
    
    func push(_ action: @escaping Action) {
        queuedActions.enqueue(action)
        dispatchQueuedActions()
    }
    
    func dispatchQueuedActions() {
        guard status == .idle else { return }
        status = .active
        while let action = queuedActions.next() {
            action()
        }
        status = .idle
    }
}
