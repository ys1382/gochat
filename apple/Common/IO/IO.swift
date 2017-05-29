
import AVFoundation
import AudioToolbox
import VideoToolbox

struct Bus {
    static let input = 0
    static let output = 1
}

struct AudioData {
    var bytes: UnsafePointer<Int8>!
    var bytesNum: UInt32 = 0
    var packetDesc: UnsafePointer<AudioStreamPacketDescription>!
    var packetNum: UInt32 = 0
    var timeStamp: UnsafePointer<AudioTimeStamp>!
}

enum H264Part : Int {
    case Time
    case SPS
    case PPS
    case Data
    case NetworkPacket // Time, SPS size, SPS, PPS size, PPS, Data size, Data
}

enum AACPart : Int {
    case NetworkPacket // Time, Packet num, Packets, Data size, Data
}

protocol AudioOutputProtocol {
    
    func process(_ data: AudioData)
}

protocol VideoOutputProtocol {
    
    func process(_ data: CMSampleBuffer)
}

protocol DataProtocol {
    
    func process(_ data: [Int: NSData])
}

enum ErrorIO : Error {
    case Error(String)
}

func logIO(_ message: String) {
    logMessage("IO", message)
}

func logIOError(_ error: Error) {
    logError("IO", error)
}

func logIOError(_ error: String) {
    logError("IO", error)
}

func checkStatus(_ status: OSStatus, _ message: String) throws {
    guard status == 0 else {
        throw ErrorIO.Error(message + ", status code \(status)")
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AudioData
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension AudioData {
    
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
