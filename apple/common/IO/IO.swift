//
//  IO.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 23/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AudioToolbox

struct IOBus {
    static let input = 0
    static let output = 1
}

struct IOAudioData {
    var bytes: UnsafePointer<Int8>!
    var bytesNum: UInt32 = 0
    var packetDesc: UnsafePointer<AudioStreamPacketDescription>!
    var packetNum: UInt32 = 0
    var timeStamp: UnsafePointer<AudioTimeStamp>!
}

protocol IOAudioOutputProtocol {
    
    func start(_ format: UnsafePointer<AudioStreamBasicDescription>,
               _ maxPacketSize: UInt32,
               _ interval: Double)
    
    func process(_ data: IOAudioData)
    
    func stop()
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOAudioData
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension IOAudioData {
    
    init(_ bytes: UnsafePointer<Int8>,
         _ bytesNum: UInt32,
         _ packetDesc: UnsafePointer<AudioStreamPacketDescription>,
         _ packetNum: UInt32,
         _ timeStamp: UnsafePointer<AudioTimeStamp>) {
        self.bytes = bytes
        self.bytesNum = bytesNum
        self.packetDesc = packetDesc
        self.packetNum = packetNum
        self.timeStamp = timeStamp
    }

    func serialize() -> NSData {
        
        var dataSize_: UInt32 = self.bytesNum
        var packetNum_: UInt32 = self.packetNum
        var timeStamp_ = self.timeStamp
        
        // calc size
        
        var size: Int = 0
        
        size += Int(MemoryLayout<UInt32>.size)
        size += Int(self.bytesNum)
        size += Int(MemoryLayout<UInt32>.size)
        size += Int(MemoryLayout<AudioStreamPacketDescription>.size * Int(self.packetNum))
        size += Int(MemoryLayout<AudioTimeStamp>.size)
        
        // copy data
        
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        var shift = 0
        
        // 1. bytes size
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(result.advanced(by: shift), &dataSize_, s)
            shift += s
        }
        
        // 2. bytes
        
        do { let s = Int(self.bytesNum)
            memcpy(result.advanced(by: shift), self.bytes, s)
            shift += s
        }
        
        // 3. packet number
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(result.advanced(by: shift), &packetNum_, s)
            shift += s
        }
        
        // 4. packet descripitons
        
        do { let s = MemoryLayout<AudioStreamPacketDescription>.size * Int(self.packetNum)
            memcpy(result.advanced(by: shift), self.packetDesc, s)
            shift += s
        }
        
        // 5. timestamp
        
        do { let s = MemoryLayout<AudioTimeStamp>.size
            memcpy(result.advanced(by: shift), &timeStamp_, s)
            shift += s
        }
        
        return NSData(bytes: result, length: size)
    }
    
    static func deserialize(_ data: NSData) -> IOAudioData {
        
        var result = IOAudioData()
        var shift = 0
        
        // 1. bytes size
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(&result.bytesNum, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 2. bytes
        
        do { let s = Int(result.bytesNum)
            let x = UnsafeMutablePointer<Int8>.allocate(capacity: s)
            
            result.bytes = UnsafePointer<Int8>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 3. packet number
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(&result.packetNum, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 4. packet descripitons
        
        do { let s = MemoryLayout<AudioStreamPacketDescription>.size * Int(result.packetNum)
            let x = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(result.packetNum))

            result.packetDesc = UnsafePointer<AudioStreamPacketDescription>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 5. timestamp
        
        do { let s = MemoryLayout<AudioTimeStamp>.size
            let x = UnsafeMutablePointer<AudioTimeStamp>.allocate(capacity: s)

            result.timeStamp = UnsafePointer<AudioTimeStamp>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        return result
        
    }
}
