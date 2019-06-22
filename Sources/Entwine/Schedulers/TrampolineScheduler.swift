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
import Foundation

// MARK: - Class definition

/// A scheduler for performing trampolined actions.
///
/// You can only use this scheduler for immediate actions. If you attempt to schedule
/// actions after a specific date, the scheduler produces a fatal error.
public final class TrampolineScheduler {
    
    public static let shared = TrampolineScheduler()
    
    private static let localThreadActionQueueKey = "com.github.tcldr.Entwine.TrampolineScheduler.localThreadActionQueueKey"
    
    private static var localThreadActionQueue: TrampolineSchedulerQueue {
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

fileprivate final class TrampolineSchedulerQueue {
    
    typealias Action = () -> Void
    enum Status { case idle, active }
    
    private var queuedActions = LinkedListQueue<Action>()
    private var status = Status.idle
    
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
