# Entwine

Accessories for [Apple's Combine Framework](https://developer.apple.com/documentation/combine).

## About
Entwine consists of three libraries to be used in conjuction with Apple's Combine framework:
- The [_Entwine_](https://github.com/tcldr/Entwine) package includes additional operators, subjects and utilities for working with Combine sequences,
including: a `ReplaySubject`, a `withLatest(from:)` operator and a `Publishers.Factory` for rapidly defining
publishers inline from any source.
- The [_EntwineTest_](https://github.com/tcldr/Entwine) package consists of tools for verifying expected behavior of Combine sequences, including:
a `TestScheduler` that uses virtual time, a `TestablePublisher` that schedules a user-defined sequence of
elements in absolute or relative time, and a `TestableSubscriber` that record a time-stamped list of events that can
be compared against expected behavior.
- The [_EntwineRx_](https://github.com/tcldr/Entwine) library is a small library that contains bridging operators from RxSwift to Combine and vice versa
and makes _RxSwift_ and _Combine_ work together seamlessly.  

## Documentation
Documentation for each package is available at:
- [Entwine Documentation](https://github.com/tcldr/Entwine) (Operators, Publishers and Accessories)
- [EntwineTest Documentation](https://github.com/tcldr/Entwine) (Tools for testing Combine sequence behavior)
- [EntwineRx Documentation](https://github.com/tcldr/Entwine) (Bridging operators for RxSwift)

## Quick start
### Make publishers from any source
Use the `Publishers.Factory` publisher from the _Entwine_ package to effortlessly create a publisher that
meets Combine's backpressure requirements from any source.

_Inline publisher creation for PhotoKit authorization status:_
```swift

import Entwine

let photoKitAuthorizationStatus = Publishers.Factory { dispatcher in
    let status = PHPhotoLibrary.authorizationStatus() 
    switch status {
    case .notDetermined:
        PHPhotoLibrary.requestAuthorization { newStatus in
            dispatcher.forward(newStatus)
            dispatcher.forwardCompletion(.finished)
        }
    case .restricted, .denied, .authorized:
        dispatcher.forward(.authorized)
        dispatcher.forwardCompletion(.finished)
    }
}
```
### Test their behavior
_Testing Combine's `map(_:)` operator_
```swift

import XCTest
import EntwineTest
    
func testMap() {
    
    let testScheduler = TestScheduler(initialClock: 0)
    
    // creates a publisher that will schedule it's elements relatively, at the point of subscription
    let testablePublisher: TestablePublisher<String, Never> = testScheduler.createRelativeTestablePublisher([
        (100, .input("a")),
        (200, .input("b")),
        (300, .input("c")),
    ])
    
    let subjectUnderTest = testablePublisher.map { $0.uppercased() }
    
    // schedules a subscription at 200, to be cancelled at 900
    let results = testScheduler.start { subjectUnderTest }
    
    XCTAssertEqual(results.sequence, [
        (200, .subscription),           // subscribed at 200
        (300, .input("A")),             // received uppercased input @ 100 + subscription time
        (400, .input("B")),             // received uppercased input @ 200 + subscription time
        (500, .input("C")),             // received uppercased input @ 300 + subscription time
        (900, .completion(.finished)),  // subscription cancelled
    ])
}


```
### Use your RxSwift models with SwiftUI
_Example to be provided_

## Requirements
Entwine sits on top of Apple's Combine framework and therefore requires _Xcode 11_ and is has minimum deployment targets of _macOS 10.15_, _iOS 13_, _tvOS 13_ or _watchOS 6_.

## Installation
Entwine is delivered via a Swift Package and can be installed either as a dependency to another Swift Package by adding it to the dependencies section of a `Package.swift`  file
or to an Xcode 11 project by via the `File -> Swift Packages -> Add package dependency...` menu in Xcode 11. 
## Acknowledgements
_EntwineTest_ is influenced by [RxSwift's](https://github.com/ReactiveX/RxSwift) 'RxTest' package. 
## License
This project is released under the [MIT license](https://github.com/tcldr/Entwine/license)

