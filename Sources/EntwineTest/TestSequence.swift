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

import Entwine

// MARK: - TestSequence definition

/// A collection of time-stamped `Signal`s
public struct TestSequence <Input, Failure: Error> {
    
    private var contents: [Element]
    
    /// Initializes the `TestSequence` with a series of tuples of the format `(VirtualTime, Signal<Input, Failure>)`
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.contents = Array(elements)
    }
    
    /// Initializes an empty `TestSequence` 
    public init() {
        self.contents = [Element]()
    }
    
    
    /// Returns a TestSequence containing the results of mapping the given closure over the sequence’s input elements.
    /// - Parameter transform: A mapping closure. `transform` accepts an element of this sequence's Input type
    /// as its parameter and returns a transformed value of the same or of a different type.
    /// - Returns: A TestSequence containing the transformed input elements
    public func mapInput<T>(_ transform: (Input) -> T) -> TestSequence<T, Failure> {
        TestSequence<T, Failure>(map { ($0.0, $0.1.mapInput(transform)) })
    }
    
    /// Returns a TestSequence containing the results of mapping the given closure over the sequence’s completion elements.
    /// - Parameter transform: A mapping closure. `transform` accepts an element of this sequence's failure type
    /// as its parameter and returns a transformed error of the same or a different type
    /// - Returns: A TestSequence containing the transformed completion elements
    public func mapFailure<T: Error>(_ transform: (Failure) -> T) -> TestSequence<Input, T> {
        TestSequence<Input, T>(map { ($0.0, $0.1.mapFailure(transform)) })
    }
}

// MARK: - Sequence conformance

extension TestSequence: Sequence {
    
    public typealias Iterator = IndexingIterator<[Element]>
    public typealias Element = (VirtualTime, Signal<Input, Failure>)
    
    public __consuming func makeIterator() -> IndexingIterator<[(VirtualTime, Signal<Input, Failure>)]> {
        contents.makeIterator()
    }
}

// MARK: - RangeReplaceableCollection conformance

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

// MARK: - ExpressibleByArrayLiteral conformance

extension TestSequence: ExpressibleByArrayLiteral {
    
    public typealias ArrayLiteralElement = Element
    
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - Equatable conformance

extension TestSequence: Equatable where Input: Equatable, Failure: Equatable {
    
    private var events: [TestEvent<Signal<Input, Failure>>] {
        map { TestEvent($0.0, $0.1) }
    }
    
    public static func == (lhs: TestSequence<Input, Failure>, rhs: TestSequence<Input, Failure>) -> Bool {
        lhs.events == rhs.events
    }
}
