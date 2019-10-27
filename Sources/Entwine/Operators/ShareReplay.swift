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

import Combine

extension Publisher {
    /// Returns a publisher as a class instance that replays previous values to new subscribers
    ///
    /// The downstream subscriber receives elements and completion states unchanged from the
    /// previous subscriber, and in addition replays the latest elements received from the upstream
    /// subscriber to any new subscribers. Use this operator when you want new subscribers to
    /// receive the most recently produced values immediately upon subscription.
    ///
    /// - Parameter maxBufferSize: The number of elements that should be buffered for
    /// replay to new subscribers
    /// - Returns: A class instance that republishes its upstream publisher and maintains a
    /// buffer of its latest values for replay to new subscribers
    public func share(replay maxBufferSize: Int) -> Publishers.ReferenceCounted<Self, ReplaySubject<Self.Output, Self.Failure>> {
        multicast { ReplaySubject<Output, Failure>(maxBufferSize: maxBufferSize) }.referenceCounted()
    }
}
