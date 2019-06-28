

# [Entwine](https://github.com/tcldr/Entwine)

Accessories for [Apple's Combine Framework](https://developer.apple.com/documentation/combine).

---

## About
Entwine consists of three libraries (over two repositories) to be used in conjuction with Apple's Combine framework:
- The [_Entwine Utilities library_](https://github.com/tcldr/Entwine/blob/master/Assets/Entwine/README.md) includes additional operators, subjects and utilities for working with Combine sequences.
The package currently includes a `ReplaySubject`, a `withLatest(from:)` operator and a `Publishers.Factory` for rapidly defining publishers inline from any source.

    **[View the README for the Entwine Utilities Library](https://github.com/tcldr/Entwine/blob/master/Assets/Entwine/README.md)**
    
- The [_EntwineTest library_](https://github.com/tcldr/Entwine/blob/master/Assets/EntwineTest/README.md) consists of tools for verifying expected behavior of Combine sequences. It houses
a `TestScheduler` that uses virtual time, a `TestablePublisher` that schedules a user-defined sequence of
elements in absolute or relative time, and a `TestableSubscriber` that record a time-stamped list of events that can be compared against expected behavior.

    **[View the README for the EntwineTest Library](https://github.com/tcldr/Entwine/blob/master/Assets/EntwineTest/README.md)**

- The [_EntwineRx library_](https://github.com/tcldr/EntwineRx/blob/master/README.md) is a small library maintained under a [separate repository](https://github.com/tcldr/EntwineRx) that contains bridging operators from RxSwift to Combine and vice versa
making _RxSwift_ and _Combine_ work together seamlessly.

    **[View the README for the EntwineRx Library](https://github.com/tcldr/EntwineRx)**



_Note: EntwineRx is maintained as a separate Swift package to minimize the SPM dependency graph_.


---

## Quick start guide
### Create _Combine_ publishers from any source
Use the [`Publishers.Factory`](https://tcldr.github.io/Entwine/EntwineDocs/Extensions/Publishers/Factory.html) publisher from the _Entwine_ package to effortlessly create a publisher that
meets Combine's backpressure requirements from any source. [Find out more about the _Entwine Utilities_ library.](https://github.com/tcldr/Entwine/blob/master/Assets/Entwine/README.md)

_Inline publisher creation for PhotoKit authorization status:_
```swift

import Entwine

let photoKitAuthorizationStatus = Publishers.Factory<PHAuthorizationStatus, Never> { dispatcher in
    let status = PHPhotoLibrary.authorizationStatus()
    dispatcher.forward(status)
    switch status {
    case .notDetermined:
        PHPhotoLibrary.requestAuthorization { newStatus in
            dispatcher.forward(newStatus)
            dispatcher.forward(completion: .finished)
        }
    default:
        dispatcher.forward(completion: .finished)
    }
    return AnyCancellable {}
}
```
### Unit test _Combine_ publisher sequences
Use the `TestScheduler`, `TestablePublisher` and `TestableSubscriber` to simulate _Combine_ sequences and test against expected output. [Find out more about the _EntwineTest_ library](https://github.com/tcldr/Entwine/blob/master/Assets/EntwineTest/README.md)

_Testing Combine's `map(_:)` operator:_

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
    ])
}
```

### Bridge your _RxSwift_ view models to _Combine_ and use with _SwiftUI_
First, make sure you add the [_EntwineRx Swift Package_](https://github.com/tcldr/EntwineRx) (located in an external repo) as a dependency to your project.

_Example coming soon_

---

## Requirements
Entwine sits on top of Apple's Combine framework and therefore requires _Xcode 11_ and is has minimum deployment targets of _macOS 10.15_, _iOS 13_, _tvOS 13_ or _watchOS 6_.

---

## Installation
Entwine is delivered via a Swift Package and can be installed either as a dependency to another Swift Package by adding it to the dependencies section of a `Package.swift`  file
or to an Xcode 11 project by via the `File -> Swift Packages -> Add package dependency...` menu in Xcode 11. 

---

## Documentation
Documentation for each package is available at:
- [Entwine Documentation](https://tcldr.github.io/Entwine/EntwineDocs/) (Operators, Publishers and Accessories)
- [EntwineTest Documentation](https://tcldr.github.io/Entwine/EntwineTestDocs/) (Tools for testing _Combine_ sequence behavior)
- [EntwineRx Documentation](https://tcldr.github.io/Entwine/EntwineRxDocs/) (Bridging operators for _RxSwift_)

---

## Copyright and license

This project is released under the [MIT license](https://github.com/tcldr/Entwine/blob/master/LICENSE)

---

