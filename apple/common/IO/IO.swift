//
//  IO.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 23/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation

struct IOBus {
    static let input = 0
    static let output = 1
}

enum IOError : Error {
    case Error(String)
}

func logIO(_ message: String) {
    logMessage("IO", message)
}

func logIOError(_ message: String) {
    logError("IO", message)
}

func checkStatus(_ status: OSStatus, _ message: String) throws {
    guard status == 0 else {
        throw IOError.Error(message)
    }
}
