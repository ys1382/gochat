
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
    
    init(_ dimention: CMVideoDimensions) {
        self.init()
        
        width = UInt32(dimention.width)
        height = UInt32(dimention.height)
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

    var dimentions: CMVideoDimensions {
        get {
            return CMVideoDimensions(width: Int32(width), height: Int32(height))
        }
    }
}

protocol VideoOutputProtocol {
    
    func process(_ data: CMSampleBuffer)
}

protocol VideoSessionProtocol : IOSessionProtocol {
    
    func update(_ outputFormat: VideoFormat) throws
}

class VideoSession : IOSession, VideoSessionProtocol {
    
    func update(_ outputFormat: VideoFormat) throws {}
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

func create(_ x: [VideoSessionProtocol]) -> VideoSessionProtocol? {
    if (x.count == 0) {
        return nil
    }
    if (x.count == 1) {
        return x.first
    }
    
    return VideoSessionBroadcast(x)
}

