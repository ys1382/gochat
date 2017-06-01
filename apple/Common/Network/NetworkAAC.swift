
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkAACSerializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkAACSerializer : AudioOutputProtocol {
 
    private let output: IODataProtocol?
    
    init(_ output: IODataProtocol?) {
        self.output = output
    }
    
    func process(_ data: AudioData) {
    
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
        
        output?.process([AACPart.NetworkPacket.rawValue: NSData(bytes: result, length: size)])
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkAACDeserializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkAACDeserializer : IODataProtocol {
    
    private let output: AudioOutputProtocol?
    
    init(_ output: AudioOutputProtocol) {
        self.output = output
    }
    
    func process(_ packets: [Int: NSData]) {
        
        let data = packets[AACPart.NetworkPacket.rawValue]!
        var result = AudioData()
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Audio format
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension AudioFormat {
    
    func toNetwork() throws -> NSData {
        return try JSONSerialization.data(withJSONObject: data,
                                          options: JSONSerialization.defaultWritingOptions) as NSData
    }
    
    static func fromNetwork(_ data: NSData) throws -> AudioFormat {
        let json = try JSONSerialization.jsonObject(with: data as Data,
                                                    options: JSONSerialization.ReadingOptions()) as! [String: Any]
        return AudioFormat(json)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudio
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudio : IODataProtocol {
    
    let to: String
    
    init(_ to: String) {
        self.to = to
    }
    
    func process(_ data: [Int: NSData]) {
        Backend.shared.sendAudio(to, data[AACPart.NetworkPacket.rawValue]!)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudioSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudioSession : IOSessionProtocol {
    
    let to: String
    let format: AudioFormat.Factory
    
    init(_ to: String, _ format: @escaping AudioFormat.Factory) {
        self.to = to
        self.format = format
    }
    
    func start() throws {
        Backend.shared.sendAudioSession(to, try format().toNetwork(), true)
    }
    
    func stop() {
        Backend.shared.sendAudioSession(to, nil, false)
    }
}
