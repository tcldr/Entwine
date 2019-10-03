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
import Entwine

// MARK: - TestableSubscriberOptions value definition

/// Options for the defining the behavior of a `TestableSubscriber` throughout its lifetime
public struct TestableSubscriberOptions {
    /// The demand that will be signalled to the upstream `Publisher` upon subscription
    public var initialDemand = Subscribers.Demand.unlimited
    /// The demand that will be signalled to the upstream `Publisher` when the initial
    /// demand is depleted
    public var subsequentDemand = Subscribers.Demand.none
    /// When demand has been depleted, the delay in virtual time before additional demand
    /// (amount determined by `.subsequentDemand) is signalled to the upstream publisher.
    public var demandReplenishmentDelay: VirtualTimeInterval = 100
    /// An action to perform when a publisher produces a greater number of elements than
    /// the subscriber has signalled demand for. The default is an assertion failure.
    public var negativeBalanceHandler: (() -> Void)? = nil
    
    /// Pre-populated `TestableSubscriber` options:
    ///
    /// The defaults are:
    /// - `initialDemand`: `.unlimited`
    /// - `subsequentDemand`: `.none`
    /// - `demandReplenishmentDelay`: `100`
    /// - `negativeBalanceHandler`: `nil`
    public static let `default` = TestableSubscriberOptions()
}

// MARK: - TestableSubscriber definition

/// A subscriber that keeps a time-stamped log of the events that occur during the lifetime of a subscription to an arbitrary publisher.
///
/// Initializable using the factory methods on `TestScheduler`
public final class TestableSubscriber<Input, Failure: Error> {
    
    public typealias Sequence = TestSequence<Input, Failure>
    
    /// A time-stamped log of `Signal`s produced during the lifetime of a subscription to a publisher.
    public internal(set) var recordedOutput = TestSequence<Input, Failure>()
    /// A time-stamped account of `Subscribers.Demand`s issued upstream, and incoming elements
    /// downstream, during the lifetime of a subscription to a publisher.
    public internal(set) var recordedDemandLog = DemandLedger<VirtualTime>()
    
    private let scheduler: TestScheduler
    private let options: TestableSubscriberOptions
    private var subscription: Subscription?
    private var demandBalance = Subscribers.Demand.none
    private var replenishmentToken: Cancellable?
    
    
    init(scheduler: TestScheduler, options: TestableSubscriberOptions = .default) {
        self.scheduler = scheduler
        self.options = options
    }
    
    deinit {
        cancel()
    }
    
    func issueDemandCredit(_ demand: Subscribers.Demand) {
        demandBalance += demand
        recordedDemandLog.append((scheduler.now, demandBalance, .credit(amount: demand)))
        guard demand > .none else { return }
        subscription?.request(demand)
    }
    
    func debitDemand(_ demand: Subscribers.Demand) {
        
        let authorized = (demandBalance > .none)
        demandBalance -= authorized ? demand : .none
        recordedDemandLog.append((scheduler.now, demandBalance, .debit(authorized: authorized)))
        if !authorized {
            signalNegativeBalance()
        }
    }
    
    func signalNegativeBalance() {
        guard let negativeBalanceHandler = options.negativeBalanceHandler else {
            assertionFailure("""
                
                **************************************************************************************

                Bad Publisher
                
                The number of items received from the publisher exceeds the number of items requested.
                
                If you wish to test acquiring this state purposefully, add a `.negativeBalanceHandler`
                to the `TestableSubscriberOptions` configuration object to silence this assertion and
                handle the state.
                
                **************************************************************************************
            """)
            return
        }
        negativeBalanceHandler()
    }
    
    func delayedReplenishDemandIfNeeded() {
        
        guard demandBalance == .none && options.subsequentDemand > .none else { return }
        guard replenishmentToken == nil else { return }
        
        replenishmentToken = scheduler.schedule(after: scheduler.now + options.demandReplenishmentDelay, interval: 0, tolerance: 1, options: nil) {
            self.issueDemandCredit(self.options.subsequentDemand)
            self.replenishmentToken = nil
        }
    }
}

// MARK: - Subscriber conformance

extension TestableSubscriber: Subscriber {
    
    public func receive(subscription: Subscription) {
        
        guard self.subscription == nil else {
            subscription.cancel()
            return
        }
        
        self.demandBalance = .none
        self.subscription = subscription
        
        recordedOutput.append((scheduler.now, .subscription))
        
        issueDemandCredit(options.initialDemand)
        delayedReplenishDemandIfNeeded()
    }
    
    public func receive(_ input: Input) -> Subscribers.Demand {
        recordedOutput.append((scheduler.now, .input(input)))
        
        debitDemand(.max(1))
        delayedReplenishDemandIfNeeded()
        
        return .none
    }
    
    public func receive(completion: Subscribers.Completion<Failure>) {
        recordedOutput.append((scheduler.now, .completion(completion)))
    }    
}

// MARK: - Cancellable conformance

extension TestableSubscriber: Cancellable {
    public func cancel() {
        replenishmentToken?.cancel()
        subscription?.cancel()
        subscription = nil
        replenishmentToken = nil
    }
}
