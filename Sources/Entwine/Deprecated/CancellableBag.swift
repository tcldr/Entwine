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

/// A container for cancellables that will be cancelled when the bag is deallocated or cancelled itself
@available(*, deprecated, message: "Replace with mutable Set<AnyCancellable>")
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class CancellableBag: Cancellable {
    
    public init() {}
    
    private var cancellables = [AnyCancellable]()
    
    /// Adds a cancellable to the bag which will have its `.cancel()` method invoked
    /// when the bag is deallocated or cancelled itself
    public func add<C: Cancellable>(_ cancellable: C) {
        cancellables.append(AnyCancellable { cancellable.cancel() })
    }
    
    /// Empties the bag and cancels each contained item
    public func cancel() {
        cancellables.removeAll()
    }
}

// MARK: - Cancellable extension

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Cancellable {
    @available(*, deprecated, message: "Replace CancellableBag with Set<AnyCancellable> and use `store(in:)`")
    func cancelled(by cancellableBag: CancellableBag) {
        cancellableBag.add(self)
    }
}

#endif
