
import AVFoundation
import AudioToolbox

struct AudioBus {
    static let input = 0
    static let output = 1
}

struct AudioData {
    var bytes: UnsafePointer<Int8>!
    var bytesNum: UInt32 = 0
    var packetDesc: UnsafePointer<AudioStreamPacketDescription>!
    var packetNum: UInt32 = 0
    var timeStamp: UnsafePointer<AudioTimeStamp>!
    
    init () {
        
    }
    
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
}

struct AudioFormat {
    
}

protocol AudioOutputProtocol {
    
    func process(_ data: AudioData)
}

enum AACPart : Int {
    case NetworkPacket // Time, Packet num, Packets, Data size, Data
}

