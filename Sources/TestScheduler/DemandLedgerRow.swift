//
//  File.swift
//  
//
//  Created by Tristan Celder on 11/06/2019.
//

import Combine

// MARK: - Value definition

public struct DemandLedgerRow<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
    
    public enum Transaction<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
        case credit(amount: Subscribers.Demand)
        case debit(authorized: Bool)
    }
    
    public let time: VirtualTime
    public let transaction: Transaction<Time>
    public let balance: Subscribers.Demand
    
    public init(_ time: VirtualTime, _ transaction: Transaction<Time>, balance: Subscribers.Demand) {
        self.time = time
        self.transaction = transaction
        self.balance = balance
    }
}

// MARK: - CustomDebugStringConvertible conformance

extension DemandLedgerRow: CustomDebugStringConvertible {
    public var debugDescription: String {
        "(\(time), \(transaction), balance: \(balance.prettyDescription()))"
    }
}

extension DemandLedgerRow.Transaction: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .credit(let amount):
            return ".credit(\(amount.prettyDescription()))"
        case .debit(let authorized):
            return ".debit(\(authorized))"
        }
    }
}

// MARK: - Subscribers.Demand helper extension

extension Subscribers.Demand {
    func prettyDescription() -> String {
        guard case .max(let amount) = self else {
            return ".unlimited"
        }
        return ".max(\(amount))"
    }
}
