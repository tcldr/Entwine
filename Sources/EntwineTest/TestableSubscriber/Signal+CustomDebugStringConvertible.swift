//
//  File.swift
//  
//
//  Created by Tristan Celder on 11/06/2019.
//

import Entwine

// MARK: - CustomDebugStringConvertible conformance

extension Signal: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .subscription:
            return ".subscribe"
        case .input(let input):
            return ".input(\(input))"
        case .completion(let completion):
            return ".completion(\(completion))"
        }
    }
}
