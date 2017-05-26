
import AVFoundation
import AudioToolbox
import VideoToolbox

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

enum IOH264Part : Int {
    case Time
    case SPS
    case PPS
    case Data
    case NetworkPacket // Time, SPS size, SPS, PPS size, PPS, Data size, Data
}

enum IOAACPart : Int {
    case NetworkPacket // Time, Packet num, Packets, Data size, Data
}

protocol IOAudioOutputProtocol {
    
    func process(_ data: IOAudioData)
}

protocol IOVideoOutputProtocol {
    
    func process(_ data: CMSampleBuffer)
}

protocol IODataProtocol {
    
    func process(_ data: [Int: NSData])
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
        throw IOError.Error(message + ", status code \(status)")
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
}
