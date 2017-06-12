
import AVFoundation
import AudioToolbox

protocol AudioOutputProtocol {
    
    func process(_ data: AudioData)
}

enum AACPart : Int {
    case NetworkPacket // Time, Packet num, Packets, Data size, Data
}

struct AudioBus {
    static let input = 0
    static let output = 1
}

struct AudioData {
    var bytes: UnsafePointer<Int8>!
    var bytesNum: UInt32 = 0
    var packetDesc: UnsafePointer<AudioStreamPacketDescription>!
    var packetNum: UInt32 = 0
    var timeStamp: AudioTimeStamp!
    
    init () {
        
    }
    
    init(_ bytes: UnsafePointer<Int8>,
         _ bytesNum: UInt32,
         _ packetDesc: UnsafePointer<AudioStreamPacketDescription>,
         _ packetNum: UInt32,
         _ timeStamp: AudioTimeStamp) {
        self.bytes = bytes
        self.bytesNum = bytesNum
        self.packetDesc = packetDesc
        self.packetNum = packetNum
        self.timeStamp = timeStamp
    }
}

struct AudioFormat {
    
    typealias Factory = () -> AudioFormat
    
    private static let kFlags = "kFlags"
    private static let kSampleRate = "kSampleRate"
    private static let kChannelCount = "kChannelCount"
    private static let kFramesPerPacket = "kFramesPerPacket"
    private static let kPacketMaxSize = "kPacketMaxSize"

    private(set) var data: [String: Any]

    init(_ x: AudioStreamBasicDescription, _ packetMaxSize: UInt32) {
        data = [String: Any]()
        
        self.flags = x.mFormatFlags
        self.sampleRate = x.mSampleRate
        self.channelCount =  x.mChannelsPerFrame
        self.framesPerPacket = x.mFramesPerPacket
        self.packetMaxSize = packetMaxSize
    }
    
    init(_ data: [String: Any]) {
        self.data = data
    }

    var flags: UInt32 {
        get {
            return data.keys.contains(AudioFormat.kFlags) ? data[AudioFormat.kFlags] as! UInt32 : 0
        }
        set {
            data[AudioFormat.kFlags] = newValue
        }
    }

    var sampleRate: Double {
        get {
            return data.keys.contains(AudioFormat.kSampleRate) ? data[AudioFormat.kSampleRate] as! Double : 0
        }
        set {
            data[AudioFormat.kSampleRate] = newValue
        }
    }

    var channelCount: UInt32 {
        get {
            return data.keys.contains(AudioFormat.kChannelCount) ? data[AudioFormat.kChannelCount] as! UInt32 : 0
        }
        set {
            data[AudioFormat.kChannelCount] = newValue
        }
    }

    var framesPerPacket: UInt32 {
        get {
            return data.keys.contains(AudioFormat.kFramesPerPacket) ? data[AudioFormat.kFramesPerPacket] as! UInt32 : 0
        }
        set {
            data[AudioFormat.kFramesPerPacket] = newValue
        }
    }

    var packetMaxSize: UInt32 {
        get {
            return data.keys.contains(AudioFormat.kPacketMaxSize) ? data[AudioFormat.kPacketMaxSize] as! UInt32 : 0
        }
        set {
            data[AudioFormat.kPacketMaxSize] = newValue
        }
    }
}

class AudioPipe : AudioOutputProtocol {
    
    var next: AudioOutputProtocol?

    func process(_ data: AudioData) {
        next?.process(data)
    }
}

class AudioTimeDeserializer : IOTimeProtocol {
    
    let packetKey: Int
    
    init(_ packetKey: Int) {
        self.packetKey = packetKey
    }
    
    func audioTime(_ packets: [Int: NSData]) -> UnsafePointer<AudioTimeStamp> {
        let s = MemoryLayout<AudioTimeStamp>.size
        let x = UnsafeMutablePointer<AudioTimeStamp>.allocate(capacity: s)
        
        memcpy(x, packets[packetKey]!.bytes, s)
        
        return UnsafePointer<AudioTimeStamp>(x)
    }
    
    func audioTime(_ packets: [Int: NSData], _ time: UnsafePointer<AudioTimeStamp>) {
        memcpy(UnsafeMutableRawPointer(mutating: packets[packetKey]!.bytes),
               time,
               MemoryLayout<AudioTimeStamp>.size)
    }

    func time(_ data: [Int : NSData]) -> Double {
        return audioTime(data).pointee.seconds()
    }
    
    func time(_ data: inout [Int: NSData], _ time: Double) {
        let audioTime = UnsafeMutablePointer<AudioTimeStamp>(mutating: self.audioTime(data))
        audioTime.pointee.seconds(time)
        self.audioTime(data, audioTime)
    }
}

