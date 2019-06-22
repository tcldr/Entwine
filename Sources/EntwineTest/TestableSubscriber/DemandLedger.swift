//
//  File.swift
//  
//
//  Created by Tristan Celder on 22/06/2019.
//

import Combine

// MARK: - TestSequence definition

public struct DemandLedger<Time: Strideable> where Time.Stride : SchedulerTimeIntervalConvertible {
    
    public enum Transaction<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
        case credit(amount: Subscribers.Demand)
        case debit(authorized: Bool)
    }
    
    private var contents: [Element]
    
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.contents = Array(elements)
    }
    
    public init() {
        self.contents = [Element]()
    }
}

// MARK: - Sequence conformance

extension DemandLedger: Sequence {
    
    public typealias Iterator = IndexingIterator<[Element]>
    public typealias Element = (VirtualTime, Subscribers.Demand, Transaction<Time>)
    
    public __consuming func makeIterator() -> IndexingIterator<[Element]> {
        contents.makeIterator()
    }
}

// MARK: - RangeReplaceableCollection conformance

extension DemandLedger: RangeReplaceableCollection {
    
    public typealias Index = Int
    
    public subscript(position: Index) -> Element {
        get { contents[position] }
        set { contents[position] = newValue }
    }
    
    public var startIndex: Index {
        contents.startIndex
    }
    
    public var endIndex: Index {
        contents.endIndex
    }
    
    public func index(after i: Index) -> Index {
        contents.index(after: i)
    }
    
    public mutating func replaceSubrange<C: Collection, R: RangeExpression>(_ subrange: R, with newElements: C) where Element == C.Element, Index == R.Bound {
        contents.replaceSubrange(subrange, with: newElements)
    }
}

// MARK: - ExpressibleByArrayLiteral conformance

extension DemandLedger: ExpressibleByArrayLiteral {
    
    public typealias ArrayLiteralElement = Element
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - Equatable conformance

extension DemandLedger: Equatable {
    
    public static func == (lhs: DemandLedger<Time>, rhs: DemandLedger<Time>) -> Bool {
        
        return lhs.contents.map(DemandLedgerRow.init) == rhs.contents.map(DemandLedgerRow.init)
    }
}

// MARK: - DemandLedgerRow definition

fileprivate struct DemandLedgerRow<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
    
    let time: VirtualTime
    let demand: Subscribers.Demand
    let transaction: DemandLedger<Time>.Transaction<Time>
    
    init(_ element: DemandLedger<Time>.Element) {
        self.time = element.0
        self.demand = element.1
        self.transaction = element.2
    }
}

extension DemandLedger.Transaction: CustomDebugStringConvertible {
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

