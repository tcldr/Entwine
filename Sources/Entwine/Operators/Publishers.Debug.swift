//
//  File.swift
//  
//
//  Created by Tristan Celder on 12/06/2019.
//

import Combine

public extension Publisher {
    
    func debug<T>(_ name: String, valueTransform: @escaping (Output) -> T) -> Publishers.HandleEvents<Self> {
        handleEvents(
            receiveSubscription: { Swift.print("'\(name)': -> subscription: \($0.combineIdentifier)") },
            receiveOutput: { Swift.print("'\(name)': -> output signal: \(valueTransform($0))") },
            receiveCompletion: { Swift.print("'\(name)': -> completion signal: \($0)") },
            receiveCancel: { Swift.print("'\(name)': -> receive cancel") },
            receiveRequest: { Swift.print("'\(name)': -> receive demand: \($0)") }
        )
    }
    
    func debug(_ name: String) -> Publishers.HandleEvents<Self> {
        debug(name, valueTransform: { $0 })
    }
    
}
