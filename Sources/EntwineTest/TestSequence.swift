//
//  File.swift
//  
//
//  Created by Tristan Celder on 22/06/2019.
//

import Entwine

public struct TestSequence <Input, Failure: Error> {
    
    private var contents: [Element]
    
    public var events: [TestEvent<Signal<Input, Failure>>] {
        map { TestEvent($0.0, $0.1) }
    }
    
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.contents = Array(elements)
    }
    
    public init() {
        self.contents = [Element]()
    }
}

extension TestSequence: Sequence {
    
    public typealias Iterator = IndexingIterator<[Element]>
    public typealias Element = (VirtualTime, Signal<Input, Failure>)
    
    public __consuming func makeIterator() -> IndexingIterator<[(VirtualTime, Signal<Input, Failure>)]> {
        contents.makeIterator()
    }
}

extension TestSequence: RangeReplaceableCollection {
    
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

extension TestSequence: ExpressibleByArrayLiteral {
    
    public typealias ArrayLiteralElement = Element
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension TestSequence: Equatable where Input: Equatable, Failure: Equatable {
    public static func == (lhs: TestSequence<Input, Failure>, rhs: TestSequence<Input, Failure>) -> Bool {
        lhs.events == rhs.events
    }
}
