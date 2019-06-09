
import Combine

// MARK: - DemandLedgerRow value definition

public enum DemandLedgerRow<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
    case credit(time: Time, amount: Subscribers.Demand, balance: Subscribers.Demand)
    case debit(time: Time, balance: Subscribers.Demand, authorized: Bool)
}

// MARK: - TestableSubscriberOptions value definition

public struct TestableSubscriberOptions {
    var initialDemand = Subscribers.Demand.unlimited
    var subsequentDemand = Subscribers.Demand.none
    var demandReplenishmentDelay: VirtualTimeInterval = 100
    var negativeBalanceHandler: (() -> Void)? = nil

    static let `default` = TestableSubscriberOptions()
}

// MARK: - TestableSubscriber definition

public final class TestableSubscriber<Upstream: Publisher> {
    
    public internal(set) var events = [TestableSubscriberEvent<Input, Failure>]()
    public internal(set) var demands = [DemandLedgerRow<VirtualTime>]()
    
    private let scheduler: TestScheduler
    private let options: TestableSubscriberOptions
    private var subscription: Subscription?
    private var demandBalance = Subscribers.Demand.none
    private var replenishmentToken: Cancellable?
    
    init(scheduler: TestScheduler, options: TestableSubscriberOptions = .default) {
        self.scheduler = scheduler
        self.options = options
    }
    
    func creditDemand(_ demand: Subscribers.Demand) {
        
        demandBalance += demand
        demands.append(.credit(time: scheduler.now, amount: demand, balance: demandBalance))
        
        subscription?.request(demand)
    }
    
    func debitDemand(_ demand: Subscribers.Demand) {
        
        let authorized = (demandBalance > .none)
        
        demandBalance -= demand
        demands.append(.debit(time: scheduler.now, balance: demandBalance, authorized: authorized))
        
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
            self.creditDemand(self.options.subsequentDemand)
            self.replenishmentToken = nil
        }
    }
}

// MARK: - Subscriber conformance

extension TestableSubscriber: Subscriber {
    
    public typealias Input = Upstream.Output
    public typealias Failure = Upstream.Failure
    
    public func receive(subscription: Subscription) {
        
        self.subscription = subscription
        self.demandBalance = .none
        
        events.append(.subscribe(time: scheduler.now))
        
        creditDemand(options.initialDemand)
        delayedReplenishDemandIfNeeded()
    }
    
    public func receive(_ input: Input) -> Subscribers.Demand {
        
        events.append(.input(time: scheduler.now, input))
        
        debitDemand(.max(1))
        delayedReplenishDemandIfNeeded()
        
        return .none
    }
    
    public func receive(completion: Subscribers.Completion<Failure>) {
        events.append(.completion(time: scheduler.now, completion))
    }    
}

// MARK: - Cancellable conformance

extension TestableSubscriber: Cancellable {
    public func cancel() {
        subscription = nil
    }
}
