
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOAudioOutputProtocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRNetworkAACSerializer : IOAudioOutputProtocol {
 
    private let output: IODataProtocol?
    
    init(_ output: IODataProtocol?) {
        self.output = output
    }
    
    func process(_ data: IOAudioData) {
    
        var dataSize_: UInt32 = data.bytesNum
        var packetNum_: UInt32 = data.packetNum
        
        // calc size
        
        var size: Int = 0
        
        size += Int(MemoryLayout<AudioTimeStamp>.size)
        size += Int(MemoryLayout<UInt32>.size)
        size += Int(MemoryLayout<AudioStreamPacketDescription>.size * Int(data.packetNum))
        size += Int(MemoryLayout<UInt32>.size)
        size += Int(data.bytesNum)
        
        // copy data
        
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: size)
        var shift = 0
        
        // 1. timestamp
        
        do { let s = MemoryLayout<AudioTimeStamp>.size
            memcpy(result.advanced(by: shift), data.timeStamp, s)
            shift += s
        }
        
        // 2. packet number
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(result.advanced(by: shift), &packetNum_, s)
            shift += s
        }
        
        // 3. packet descripitons
        
        do { let s = MemoryLayout<AudioStreamPacketDescription>.size * Int(data.packetNum)
            memcpy(result.advanced(by: shift), data.packetDesc, s)
            shift += s
        }
        
        // 4. bytes size
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(result.advanced(by: shift), &dataSize_, s)
            shift += s
        }
        
        // 5. bytes
        
        do { let s = Int(data.bytesNum)
            memcpy(result.advanced(by: shift), data.bytes, s)
            shift += s
        }

        // output
        
        output?.process([IOAACPart.NetworkPacket.rawValue: NSData(bytes: result, length: size)])
    }
}

class TRNetworkAACDeserializer : IODataProtocol {
    
    private let output: IOAudioOutputProtocol?
    
    init(_ output: IOAudioOutputProtocol) {
        self.output = output
    }
    
    func process(_ packets: [Int: NSData]) {
        
        let data = packets[IOAACPart.NetworkPacket.rawValue]!
        var result = IOAudioData()
        var shift = 0
        
        // 1. timestamp
        
        do { let s = MemoryLayout<AudioTimeStamp>.size
            let x = UnsafeMutablePointer<AudioTimeStamp>.allocate(capacity: s)
            
            result.timeStamp = UnsafePointer<AudioTimeStamp>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }

        // 2. packet number
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(&result.packetNum, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 3. packet descripitons
        
        do { let s = MemoryLayout<AudioStreamPacketDescription>.size * Int(result.packetNum)
            let x = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(result.packetNum))
            
            result.packetDesc = UnsafePointer<AudioStreamPacketDescription>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 4. bytes size
        
        do { let s = MemoryLayout<UInt32>.size
            memcpy(&result.bytesNum, data.bytes.advanced(by: shift), s)
            shift += s
        }
        
        // 5. bytes
        
        do { let s = Int(result.bytesNum)
            let x = UnsafeMutablePointer<Int8>.allocate(capacity: s)
            
            result.bytes = UnsafePointer<Int8>(x)
            memcpy(x, data.bytes.advanced(by: shift), s)
            shift += s
        }

        // output
        
        output?.process(result)
    }

}

