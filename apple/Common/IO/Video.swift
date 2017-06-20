
import AVFoundation
import VideoToolbox

enum VideoPart : Int {
    case NetworkPacket = 8 // Time, SPS size, SPS, PPS size, PPS, Data size, Data
}

enum H264Part : Int {
    case SPS = 64
    case PPS = 128
    case Data = 256
}

struct VideoFormat : Equatable {
    
    private static let kWidth = "width"
    private static let kHeight = "height"
    
    private(set) var data: [String: Any]
    
    init () {
        data = [String: Any]()
    }
    
    init(_ dimension: CMVideoDimensions) {
        self.init()
        
        width = UInt32(dimension.width)
        height = UInt32(dimension.height)
    }
    
    init(_ data: [String: Any]) {
        self.data = data
    }
    
    public static func ==(lhs: VideoFormat, rhs: VideoFormat) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.width
        
    }

    public static func !=(lhs: VideoFormat, rhs: VideoFormat) -> Bool {
        return false == (lhs == rhs)
    }
    
    var width: UInt32 {
        get {
            return data.keys.contains(VideoFormat.kWidth) ? data[VideoFormat.kWidth] as! UInt32 : 0
        }
        set {
            data[VideoFormat.kWidth] = newValue
        }
    }
    
    var height: UInt32 {
        get {
            return data.keys.contains(VideoFormat.kHeight) ? data[VideoFormat.kHeight] as! UInt32 : 0
        }
        set {
            data[VideoFormat.kHeight] = newValue
        }
    }

    var dimensions: CMVideoDimensions {
        get {
            return CMVideoDimensions(width: Int32(width), height: Int32(height))
        }
    }
    
    mutating func rotate() {
        swap(&width, &height)
    }
}

protocol VideoOutputProtocol {
    
    func process(_ data: CMSampleBuffer)
}

protocol VideoSessionProtocol : IOSessionProtocol {
    
    func update(_ outputFormat: VideoFormat) throws
}

class VideoSession : IOSession, VideoSessionProtocol {

    private let next: VideoSessionProtocol?
    override init() { next = nil; super.init() }
    init(_ next: VideoSessionProtocol?) { self.next = next; super.init(next) }
    func update(_ outputFormat: VideoFormat) throws { try next?.update(outputFormat) }
}

class VideoSessionBroadcast : IOSessionBroadcast, VideoSessionProtocol {
    
    var x: [VideoSessionProtocol?]
    
    init(_ x: [VideoSessionProtocol?]) {
        self.x = x
        super.init(x)
    }
    
    func update(_ outputFormat: VideoFormat) throws {
        _ = try x.map({ try $0?.update(outputFormat) })
    }
}

class VideoSessionAsyncDispatcher : IOSessionAsyncDispatcher, VideoSessionProtocol {
    
    private let next: VideoSessionProtocol?
    
    init(_ queue: DispatchQueue, _ next: VideoSessionProtocol?) {
        self.next = next
        super.init(queue, next)
    }

    func update(_ outputFormat: VideoFormat) throws {
        queue.async{ do { try self.next?.update(outputFormat) } catch { logIOError(error) } }
    }
}

func create(_ x: [VideoSessionProtocol]) -> VideoSessionProtocol? {
    if (x.count == 0) {
        return nil
    }
    if (x.count == 1) {
        return x.first
    }
    
    return VideoSessionBroadcast(x)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Time
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct VideoTime : IOTimeProtocol {
    let time: IOTime
    let timeScale: Int32
    
    init() {
        time = IOTime()
        timeScale = 0
    }
    
    init(_ hostSeconds: Float64, _ timeScale: Int32) {
        self.time = IOTime(hostSeconds)
        self.timeScale = timeScale
    }
    
    func copy(time: IOTime) -> VideoTime {
        return VideoTime(time.hostSeconds, timeScale)
    }
}

extension VideoTime {
    
    init(_ x: CMSampleTimingInfo) {
        self.init(CMTimeGetSeconds(x.presentationTimeStamp), x.presentationTimeStamp.timescale)
    }
    
    func ToCMSampleTimingInfo() -> CMSampleTimingInfo {
        var result = CMSampleTimingInfo()
        result.presentationTimeStamp.flags = .valid
        result.presentationTimeStamp.timescale = timeScale
        CMTimeSetSeconds(&result.presentationTimeStamp, time.hostSeconds)
        
        return result
    }
}

extension VideoTime : InitProtocol {}
extension VideoTime : SerializableProtocol {}
typealias VideoTimeSerializer = IOTimeSerializer<AudioTime>

