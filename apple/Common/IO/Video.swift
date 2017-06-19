
import AVFoundation
import VideoToolbox

enum H264Part : Int {
    case Time
    case SPS
    case PPS
    case Data
    case NetworkPacket // Time, SPS size, SPS, PPS size, PPS, Data size, Data
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

class VideoTimeDeserializer : IOTimeProtocol {
    
    let packetKey: Int
    
    init(_ packetKey: Int) {
        self.packetKey = packetKey
    }
    
    static let Size = UInt32(MemoryLayout<CMSampleTimingInfo>.size)
    
    func videoTime(_ packets: [Int: NSData]) -> CMSampleTimingInfo {
        return CMSampleTimingInfo(packets[packetKey]!)
    }

    func videoTime(_ packets: inout [Int: NSData], _ time: CMSampleTimingInfo) {
        packets[packetKey] = time.toNSData()
    }

    func time(_ packets: [Int : NSData]) -> Double {
        return CMTimeGetSeconds(videoTime(packets).presentationTimeStamp)
    }
    
    func time(_ data: inout [Int: NSData], _ time: Double) {
        var videoTime = self.videoTime(data)
        CMTimeSetSeconds(&videoTime.presentationTimeStamp, time)
        self.videoTime(&data, videoTime)
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

