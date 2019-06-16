//
//  File.swift
//  
//
//  Created by Tristan Celder on 13/06/2019.
//

// MARK: - LinkedList definition

/// Value based linked list data structure. Effective as a LIFO Queue.
struct LinkedListStack<Element> {
    
    typealias Node = LinkedList<Element>
    
    private (set) var node = Node.empty
    private (set) var count: Int = 0
    
    init<C: Collection>(_ elements: C) where C.Element == Element {
        node = LinkedList(elements)
        count = elements.count
    }
    
    func peek() -> Element? {
        node.value
    }
    
    mutating func push(_ element: Element) {
        node.prepend(element)
        count += 1
    }
}

// MARK: - IteratorProtocol conformance

extension LinkedListStack: IteratorProtocol {
    
    mutating func next() -> Element? {
        guard let value = node.poll() else { return nil }
        count -= 1
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

public indirect enum LinkedList<Element> {
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

