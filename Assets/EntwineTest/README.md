
# Entwine Test

Part of [Entwine](https://github.com/tcldr/Entwine) – A collection of accessories for [Apple's Combine Framework](https://developer.apple.com/documentation/combine).

---

### CONTENTS
- [About _EntwineTest_](#about-entwinetest)
- [Getting Started](#getting-started)
    - [TestScheduler](#testscheduler)
    - [TestablePublisher](#testablepublisher)
    - [TestableSubscriber](#testablesubscriber)
    - [Putting it all together](#putting-it-all-together)
- [Installation](#installation)
- [Documentation](#documentation)
- [Acknowledgements](#acknowledgements)
- [Copyright and License](#copyright-and-license)

---

### ABOUT _ENTWINE TEST_

_EntwineTest_ packages a concise set of tools that are designed to work together to help you test your _Combine_ sequences and operators.

In addition, _EntwineTest_ includes tools to help you to determine whether your publishers are complying with subscriber demand requests (backpressure) so that you can ensure your publisher is behaving like a good _Combine_ citizen before releasing it out in the wild.

---

### GETTING STARTED

The _EntwineTest_ packages consists of three major components – together, they help you write better tests for your _Combine_ sequences.

Let's go through them one by one before finally seeing how they all fit together:

## `TestScheduler`:

At the heart of _Combine_ is the concept of schedulers. Without them, no work gets done. Essentially they are responsible for both _where_ an action is excuted (main thread, a dipatch queue, or the current thread), and _when_ it is is executed (right now, after the current task has finished, five minutes from now).

Our `TestScheduler` is a special kind of scheduler that uses 'virtual time' to schedule its tasks on the current thread. Our `VirtualTime` is really just an `Int` and its only purpose is to prioritise the order in which tasks are done. However, for testing purposes, we pretend it is _actual time_, as it helps us to articulate the seqeunce in which we'd like our tests to run.

The best thing about virtual time? It's instantaneous! So we keep our test suites lean and fast.

Here's how you might use the `TestScheduler` in isolation:

```swift
import EntwineTest

let scheduler = TestScheduler()

scheduler.schedule(after: 300) { print("bosh") }
scheduler.schedule(after: 200) { print("bash") }
scheduler.schedule(after: 100) { print("bish") }

scheduler.resume() // the clock is paused until this is called

// outputs:
//  "bish"
//  "bash"
//  "bosh"

```
Notice that as we've scheduled "bosh" to print at `300`, and "bish" to print at `100`, when we start the scheduler by calling `.resume()`, "bish" is printed first.
## `TestablePublisher`:

Now that we have our scheduler, we can think about how we're going to simulate some _Combine_ sequences. If we want to simulate a sequence, we'll need a publisher that lets us define _what_ each element a sequence should be, and _when_ that element should be emitted.

A `TestablePublisher` is exactly that.

You can generate a `TestablePublisher` from two factory methods on the `TestScheduler`. (We do it this way instead of instantiating directly as they depend on the scheduler.)

One, `createAbsoluteTestablePublisher(_:)`, schedules events at exactly the time specified – if the time of an event has passed at the point the publisher is subscribed to, that event won't be fired. 

The other, `createRelativeTestablePublisher(_:)`, schedules events at the time specified _plus_ the time the publisher was subscribed to. So an event scheduled at `100` with a subscription at `200` means the event will fire at `300`.

```swift
import Combine
import EntwineTest

// we'll set the schedulers clock a little forward – at 200

let scheduler = TestScheduler(initialClock: 200)

let relativeTimePublisher: TestablePublisher<String, Never> = scheduler.createRelativeTestablePublisher([
    (020, .input("Mi")),
    (030, .input("Fa")),
])

let absoluteTimePublisher: TestablePublisher<String, Never> = scheduler.createAbsoluteTestablePublisher([
    (200, .input("Do")),
    (210, .input("Re")),
])

let relativeSubscription = relativeTimePublisher.sink { element in
    print("time: \(scheduler.now) - \(element)")
}

let absoluteSubscription = absoluteTimePublisher.sink { element in
    print("time: \(scheduler.now) - \(element)")
}

scheduler.resume()

// Outputs:
//    time: 200 - Do
//    time: 210 - Re
//    time: 220 - Mi
//    time: 230 - Fa
```
Notice how the events events scheduled by the relative publisher fired _after_ the events scheduled by the absolute publisher. As we had set the time of our scheduler to `200` in its initializer, when we subscribed to our relative publisher with the `sink(_:)` method, our publisher took the current time and added that value to each scheduled event.

## `TestableSubscriber`:

The final piece in the jigsaw is the `TestableSubscriber`. Its role is to gather the output of a publisher so that it can be compared against some expected output. It also depends on the `TestScheduler`, so to get one we call `createTestableSubscriber(_:_:)` on our scheduler.

Once we subscribe to a publisher, `TestableSubscriber` records all the events with their time of arrival and makes them available on its `.sequence` property ready for us to compare against some expected output. It also records the time the subscription began, as well as its completion (should it end). 

```swift
import Combine
import EntwineTest

let scheduler = TestScheduler()
let passthroughSubject = PassthroughSubject<String, Never>()

scheduler.schedule(after: 100) { passthroughSubject.send("yippee") }
scheduler.schedule(after: 200) { passthroughSubject.send("ki") }
scheduler.schedule(after: 300) { passthroughSubject.send("yay") }

let subscriber = scheduler.createTestableSubscriber(String.self, Never.self)

passthroughSubject.subscribe(subscriber)

scheduler.resume()

let expected: TestSequence<String, Never> = [
    (000, .subscription),
    (100, .input("yippee")),
    (200, .input("ki")),
    (300, .input("yay")),
]

print("sequences match: \(expected == subscriber.sequence)")

// outputs:
//  sequences match: true
```

## Putting it all together
Now that we have our `TestScheduler`, `TestPublisher`, and `TestSubscriber` let's put them together to test our operators and sequences.

But first, there's one additional method that you should be aware of. That's the `start(create:)` method on `TestScheduler`.

The `start(create:)` method accepts a closure that produces any publisher and then:
1. Schedules the creation of the publisher (invocation of the passed closure) at `100`
2. Schedules the subscription of the publisher to a `TestableSubscriber` at `200`
3. Schedules the cancellation of the subscription at `900`
4. Resumes the scheduler clock

_These are all configurable by using the `start(configuration:create:)` method. See the docs for more info._

With that knowledge in place, let's test _Combine_'s map operator. (I'm sure it's fine – but just in case.)

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
    
    // a publisher that maps strings to uppercase
    let subjectUnderTest = testablePublisher.map { $0.uppercased() }
    
    // uses the method described above (schedules a subscription at 200, to be cancelled at 900)
    let results = testScheduler.start { subjectUnderTest }
    
    XCTAssertEqual(results.sequence, [
        (200, .subscription),           // subscribed at 200
        (300, .input("A")),             // received uppercased input @ 100 + subscription time
        (400, .input("B")),             // received uppercased input @ 200 + subscription time
        (500, .input("C")),             // received uppercased input @ 300 + subscription time
    ])
}
```
Hopefully this should be everything you need to get you started with testing your _Combine_ sequences. Don't forget that further information can be found [in the docs](http://tcldr.github.io/Entwine/EntwineTestDocs).

---

### INSTALLATION
### As part of another Swift Package:
1. Include it in your `Package.swift` file as both a dependency and a dependency of your target.

```swift
import PackageDescription

let package = Package(
    ...
    dependencies: [
        .package(url: "http://github.com/tcldr/Entwine.git", .upToNextMajor(from: "0.0.0")),
    ],
    ...
    targets: [
        .testTarget(name: "MyTestTarget", dependencies: ["EntwineTest"]),
    ]
)
```

2. Then run `swift package update` from the root directory of your SPM project. If you're using Xcode 11 to edit your SPM project this should happen automatically.

### As part of an Xcode 11 or greater project:
1. Select the `File -> Swift Packages -> Add package dependency...` menu item.
2. Enter the repository url `https://github.com/tcldr/Entwine` and tap next.
3. Select 'version, 'up to next major', enter `0.0.0`, hit next.
4. Select the _EntwineTest_ library and specify the target you wish to use it with.

*n.b. _EntwineTest_ is pre-release software and as such the API may change prior to reaching 1.0. For finer-grained control please use `.upToNextMinor(from:)` in your SPM dependency declaration*

---

### DOCUMENTATION
Full documentation for _EntwineTest_ can be found at [http://tcldr.github.io/Entwine/EntwineTestDocs](http://tcldr.github.io/Entwine/EntwineTestDocs).

---

### ACKNOWLEDGEMENTS
_EntwineTest_ is inspired by the great work done in the _RxTest_ library by the contributors to [_RxSwift_](https://github.com/ReactiveX/RxSwift).

---

### COPYRIGHT AND LICENSE
Copyright 2019 © Tristan Celder

_EntwineTest_ is made available under the [MIT License](http://github.com/tcldr/Entwine/blob/master/LICENSE)

---
