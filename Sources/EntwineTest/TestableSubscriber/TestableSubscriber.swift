
import Combine
import Entwine

// MARK: - TestableSubscriberOptions value definition

public struct TestableSubscriberOptions {
    public var initialDemand = Subscribers.Demand.unlimited
    public var subsequentDemand = Subscribers.Demand.none
    public var demandReplenishmentDelay: VirtualTimeInterval = 100
    public var negativeBalanceHandler: (() -> Void)? = nil

    public static let `default` = TestableSubscriberOptions()
}

// MARK: - TestableSubscriber definition

public final class TestableSubscriber<Input, Failure: Error> {
    
    public typealias Sequence = TestSequence<Input, Failure>
    
    public internal(set) var sequence = TestSequence<Input, Failure>()
    public internal(set) var demands = DemandLedger<VirtualTime>()
    
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
        demands.append((scheduler.now, demandBalance, .credit(amount: demand)))
        
        subscription?.request(demand)
    }
    
    func debitDemand(_ demand: Subscribers.Demand) {
        
        let authorized = (demandBalance > .none)
        
        demandBalance -= demand
        demands.append((scheduler.now, demandBalance, .debit(authorized: authorized)))
        
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
        
        sequence.append((scheduler.now, .subscription))
        
        issueDemandCredit(options.initialDemand)
        delayedReplenishDemandIfNeeded()
    }
    
    public func receive(_ input: Input) -> Subscribers.Demand {
        
        sequence.append((scheduler.now, .input(input)))
        
        debitDemand(.max(1))
        delayedReplenishDemandIfNeeded()
        
        return .none
    }
    
    public func receive(completion: Subscribers.Completion<Failure>) {
        sequence.append((scheduler.now, .completion(completion)))
        subscription = nil
    }    
}

// MARK: - Cancellable conformance

extension TestableSubscriber: Cancellable {
    public func cancel() {
        replenishmentToken?.cancel()
        subscription?.cancel()
    }
}
