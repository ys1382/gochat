
import AVFoundation
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simple types
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

protocol AudioOutputProtocol {
    
    func process(_ data: AudioData)
}

enum AudioPart : Int {
    case Timestamp = 2
    case NetworkPacket = 8 // Time, Packet num, Packets, Data size, Data
}

struct AudioBus {
    static let input = 0
    static let output = 1
}

struct AudioData {
    let time: AudioTimeStamp!
    let data: NSData!
    let desc: [AudioStreamPacketDescription]?
    
    init(_ time: AudioTimeStamp,
         _ data: NSData,
         _ desc: [AudioStreamPacketDescription]?) {
        self.time = time
        self.data = data
        self.desc = desc
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AudioFormat
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct AudioFormat {
    
    typealias Factory = () throws -> AudioFormat
    
    private static let kFormatID = "kFormatID"
    private static let kFlags = "kFlags"
    private static let kSampleRate = "kSampleRate"
    private static let kChannelCount = "kChannelCount"
    private static let kFramesPerPacket = "kFramesPerPacket"

    private(set) var data: [String: Any]

    init(_ x: AudioStreamBasicDescription) {
        data = [String: Any]()
        
        self.formatID = x.mFormatID
        self.flags = x.mFormatFlags
        self.sampleRate = x.mSampleRate
        self.channelCount =  x.mChannelsPerFrame
        self.framesPerPacket = x.mFramesPerPacket
    }
    
    init(_ data: [String: Any]) {
        self.data = data
    }

    var formatID: UInt32 {
        get {
            return data.keys.contains(AudioFormat.kFormatID) ? data[AudioFormat.kFormatID] as! UInt32 : 0
        }
        set {
            data[AudioFormat.kFormatID] = newValue
        }
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
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Time
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct AudioTime : IOTimeProtocol {
    let time: IOTime
    let sampleTime: Float64
    
    init() {
        time = IOTime()
        sampleTime = 0
    }
    
    init(_ hostSeconds: Float64, _ sampleTime: Float64) {
        self.time = IOTime(hostSeconds)
        self.sampleTime = sampleTime
    }
    
    func copy(time: IOTime) -> AudioTime {
        return AudioTime(time.hostSeconds, sampleTime)
    }
}

extension AudioTime {
    
    init(_ x: AudioTimeStamp) {
        self.init(x.seconds(), x.mSampleTime)
    }
    
    func ToAudioTimeStamp() -> AudioTimeStamp {
        var result = AudioTimeStamp()
        
        result.mHostTime = mach_absolute_time(seconds: time.hostSeconds)
        result.mSampleTime = sampleTime
        result.mFlags = AudioTimeStampFlags.sampleTimeValid.intersection(.hostTimeValid)
        
        return result
    }
}

extension AudioTime : InitProtocol {}
typealias AudioTimeSerializer = IOTimeSerializer<AudioTime>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Protocols adapters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AudioPipe : AudioOutputProtocol {
    
    var next: AudioOutputProtocol?

    func process(_ data: AudioData) {
        next?.process(data)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AudioDataBuffer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AudioDataReader {
    
    var data = [AudioData]()
    var capacity: Int
    var current: AudioData?
    var currentIndex: Int = 0
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func push(_ data: AudioData) {
        self.data.append(data)
        
        if self.data.count > capacity {
            self.data.removeLast()
        }
    }
    
    private func popFirst() -> AudioData? {
        let result = data.first
        
        if data.count != 0 {
            data.removeFirst()
        }
        
        return result
    }
    
    func pop(_ count: Int, _ outData: UnsafeMutableRawPointer) {
        
        if current == nil {
            current = popFirst()
            currentIndex = 0
        }
        
        if current == nil {
            memset(outData, 0, count)
            return
        }
        
        var countRead = min(count, Int(current!.data.length) - currentIndex)
        var outIndex = 0
        
        while current != nil && countRead > 0 {
            memcpy(outData.advanced(by: outIndex), current?.data.bytes.advanced(by: currentIndex), countRead)
            currentIndex += countRead
            outIndex += countRead
            
            if currentIndex == Int(current!.data.length) {
                current = popFirst()
                currentIndex = 0
            }
            
            if current != nil {
                countRead = min(count - outIndex, Int(current!.data.length) - currentIndex)
            }
            else {
                memset(outData.advanced(by: outIndex), 0, count - outIndex)
            }
        }
    }
}
