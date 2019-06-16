//
//  File.swift
//  
//
//  Created by Tristan Celder on 16/06/2019.
//

import Combine

extension Publisher {
    public func share(replay maxBufferSize: Int) -> Publishers.Multicast<Self, ReplaySubject<Output, Failure>> {
        multicast { ReplaySubject<Output, Failure>(maxBufferSize: maxBufferSize) }
    }
}
