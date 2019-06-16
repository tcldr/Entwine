//
//  File.swift
//  
//
//  Created by Tristan Celder on 13/06/2019.
//

// MARK: - LinkedListQueue definition

/// FIFO Queue based on a dual linked-list data structure
struct LinkedListQueue<Element> {
    
    static var empty: LinkedListQueue<Element> { LinkedListQueue<Element>() }
    
    typealias Subnode = LinkedList<Element>
    
    private var regular = Subnode.empty
    private var inverse = Subnode.empty
    private (set) var count = 0
    
    /// O(n) where n is the length of the sequence
    init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.inverse = LinkedList(elements.reversed())
        self.regular = .empty
    }
    
    /// This is an O(1) operation
    var isEmpty: Bool {
        switch (regular, inverse) {
        case (.empty, .empty):
            return true
        default:
            return false
        }
    }
    
    /// This is an O(1) operation
    mutating func enqueue(_ element: Element) {
        inverse = .value(element, tail: inverse)
        count += 1
    }
    
    /// This is an O(1) operation
    mutating func dequeue() -> Element? {
        // Assuming the entire queue is consumed this is actually an O(1) operation.
        // This is because each element only passes through the expensive O(n) reverse
        // operation a single time and remains there until ready to be dequeued.
        switch (regular, inverse) {
        case (.empty, .empty):
            return nil
        case (.value(let head, let tail), _):
            regular = tail
            count -= 1
            return head
        default:
            regular = inverse.reversed
            inverse = .empty
            return dequeue()
        }
    }
}

// MARK: - Sequence conformance

extension LinkedListQueue: Sequence {
    
    typealias Iterator = Self
    
    __consuming func makeIterator() -> LinkedListQueue<Element> {
        return self
    }
}

// MARK: - IteratorProtocol conformance

extension LinkedListQueue: IteratorProtocol {
    
    mutating func next() -> Element? {
        return dequeue()
    }
}

// MARK: - ExpressibleByArrayLiteral conformance

extension LinkedListQueue: ExpressibleByArrayLiteral {
    
    typealias ArrayLiteralElement = Element
    
    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
