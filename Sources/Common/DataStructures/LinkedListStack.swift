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

// MARK: - LinkedList definition

/// Value based linked list data structure. Effective as a LIFO Queue.
struct LinkedListStack<Element> {
    
    typealias Node = LinkedList<Element>
    
    private (set) var node = Node.empty
    
    init<C: Collection>(_ elements: C) where C.Element == Element {
        node = LinkedList(elements)
    }
    
    func peek() -> Element? {
        node.value
    }
    
    mutating func push(_ element: Element) {
        node.prepend(element)
    }
}

// MARK: - IteratorProtocol conformance

extension LinkedListStack: IteratorProtocol {
    
    mutating func next() -> Element? {
        guard let value = node.poll() else { return nil }
        return value
    }
}

// MARK: - Sequence conformance

extension LinkedListStack: Sequence {
    
    typealias Iterator = Self
    
    __consuming func makeIterator() -> Self {
        return self
    }
}

// MARK: - ExpressibleByArrayLiteral conformance

extension LinkedListStack: ExpressibleByArrayLiteral {
    
    typealias ArrayLiteralElement = Element
    
    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - LinkedListNode definition

indirect enum LinkedList<Element> {
    case value(Element, tail: LinkedList<Element>)
    case empty
}

extension LinkedList {
    
    typealias Index = Int
    
    init<S: Sequence>(_ elements: S) where S.Element == Element {
        self = elements.reduce(Self.empty) { acc, element in .value(element, tail: acc) }
    }
    
    var isEmpty: Bool {
        guard case .empty = self else { return false }
        return true
    }
    
    var reversed: Self {
        Self.reverse(self)
    }
    
    var value: Element? {
        guard case .value(let head, _) = self else { return nil }
        return head
    }
    
    var tail: LinkedList<Element>? {
        guard case .value(_, let tail) = self else { return nil }
        return tail
    }
    
    mutating func prepend(_ element: Element) {
        self = .value(element, tail: self)
    }
    
    mutating func poll() -> Element? {
        guard case .value(let head, let tail) = self else { return nil }
        self = tail
        return head
    }
    
    private static func reverse(_ node: Self, accumulator: Self = .empty) -> Self {
        guard case .value(let head, let tail) = node else { return accumulator }
        return reverse(tail, accumulator: .value(head, tail: accumulator))
    }
}

