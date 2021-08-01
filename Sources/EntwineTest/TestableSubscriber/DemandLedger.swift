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

#if canImport(Combine)

import Combine

// MARK: - TestSequence definition

/// A sequence of `Subscribers.Demand` transactions.
///
/// `DemandLedger`'s can be compared to see if they match expectations.
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct DemandLedger<Time: Strideable> where Time.Stride : SchedulerTimeIntervalConvertible {
    
    /// The kind of transcation for a `DemandLedger`
    ///
    /// - `.credit(amount:)`: The raise in authorized demand issued by a `Subscriber`.
    /// - `.debit(authorized:)`: The consumption of credit by an upstream `Publisher`. The debit is only considered authorised if the overall
    /// credit is greater or equal to the total debit over the lifetime of a subscription. A `debit` always has an implicit amount of `1`.
    public enum Transaction<Time: Strideable>: Equatable where Time.Stride : SchedulerTimeIntervalConvertible {
        case credit(amount: Subscribers.Demand)
        case debit(authorized: Bool)
    }
    
    private var contents: [Element]
    
    
    /// Initializes a pre-populated `DemandLedger`
    /// - Parameter elements: A sequence of elements of the format `(VirtualTime, Subscribers.Demand, Transaction<Time>)`
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.contents = Array(elements)
    }
    
    /// Initializes an empty `DemandLedger`
    public init() {
        self.contents = [Element]()
    }
}

// MARK: - Sequence conformance

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension DemandLedger: Sequence {
    
    public typealias Iterator = IndexingIterator<[Element]>
    public typealias Element = (VirtualTime, Subscribers.Demand, Transaction<Time>)
    
    public __consuming func makeIterator() -> IndexingIterator<[Element]> {
        contents.makeIterator()
    }
}

// MARK: - RangeReplaceableCollection conformance

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension DemandLedger: ExpressibleByArrayLiteral {
    
    public typealias ArrayLiteralElement = Element
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - Equatable conformance

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension DemandLedger: Equatable {
    
    public static func == (lhs: DemandLedger<Time>, rhs: DemandLedger<Time>) -> Bool {
        
        return lhs.contents.map(DemandLedgerRow.init) == rhs.contents.map(DemandLedgerRow.init)
    }
}

// MARK: - DemandLedgerRow definition

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Subscribers.Demand {
    func prettyDescription() -> String {
        guard let max = max else {
            return ".unlimited"
        }
        return ".max(\(max))"
    }
}

#endif
