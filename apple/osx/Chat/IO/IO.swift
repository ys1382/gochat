//
//  AudioProtocol.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation

struct IOBus {
    static let input = 0
    static let output = 1
}

protocol IOProtocol
{
    func start()
    func stop()
}

func checkError(_ status: OSStatus) -> Bool
{
    if status != noErr
    {
        print("Error " + status.description)
        return true
    }
    else
    {
        return false
    }
}
