
# Entwine Utilities

Part of [Entwine](https://github.com/tcldr/Entwine) – A collection of accessories for [Apple's Combine Framework](https://developer.apple.com/documentation/combine).

---

### CONTENTS
- [About](#about)
- [Getting Started](#getting-started)
- [Installation](#installation)
- [Documentation](#documentation)
- [Copyright and License](#copyright-and-license)

---

### ABOUT

_Entwine Utilities_ are a collection of operators, tools and extensions to make working with _Combine_ even more productive.

- The `ReplaySubject` makes it simple for subscribers to receive the most recent values immediately upon subscription.
- The `withLatest(from:)` operator enables state to be taken alongside UI events.
- `Publishers.Factory` makes creating publishers fast and simple – they can even be created inline!
- `CancellableBag` helps to gather all your cancellable in a single place and helps to make your publisher chain declarations even clearer.

be sure to checkout the [documentation](http://tcldr.github.io/Entwine/EntwineDocs) for the full list of operators and utilities.

---

### GETTING STARTED

Ensure to `import Entwine` in each file you wish to the utilities with.

The operators can then be used as part of your usual publisher chain declaration:

```swift

import Combine
import Entwine

class MyClass {

    let myEntwineCancellationBag = CancellationBag()
    
    ...

    func printLatestColorOnClicks() {
        let clicks: AnyPublisher<Void, Never> = SomeClickPublisher.shared
        let color: AnyPublisher<UIColor, Never> = SomeColorSource.shared

        clicks.withLatest(from: color)
            .sink {
                print("clicked when the latest color was: \($0)")
            }
            .cancelled(by: myEntwineCancellationBag)
    }
}

```

Each operator, subject and utility is documented with examples. check out the [full documentation.](https://tcldr.github.io/Enwtine/EntwineDocs)

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
        .target(name: "MyTarget", dependencies: ["Entwine"]),
    ]
)
```

2. Then run `swift package update` from the root directory of your SPM project. If you're using Xcode 11 to edit your SPM project this should happen automatically.

### As part of an Xcode 11 or greater project:
1. Select the `File -> Swift Packages -> Add package dependency...` menu item.
2. Enter the repository url `https://github.com/tcldr/Entwine` and tap next.
3. Select 'version, 'up to next major', enter `0.0.0`, hit next.
4. Select the _Entwine_ library and specify the target you wish to use it with.

*n.b. _Entwine_ is pre-release software and as such the API may change prior to reaching 1.0. For finer-grained control please use `.upToNextMinor(from:)` in your SPM dependency declaration*

---

### DOCUMENTATION
Full documentation for _Entwine_ can be found at [http://tcldr.github.io/Entwine/EntwineDocs](http://tcldr.github.io/Entwine/EntwineDocs).

---

### COPYRIGHT AND LICENSE
Copyright 2019 © Tristan Celder

_Entwine_ is made available under the [MIT License](http://github.com/tcldr/Entwine/blob/master/LICENSE)

---
