
import AVFoundation
import VideoToolbox

enum H264Part : Int {
    case Time
    case SPS
    case PPS
    case Data
    case NetworkPacket // Time, SPS size, SPS, PPS size, PPS, Data size, Data
}

struct VideoFormat {
    
    private static let kWidth = "width"
    private static let kHeight = "height"
    
    private(set) var data: [String: Any]
    
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
    
    init(_ dimention: CMVideoDimensions) {
        data = [String: Any]()
        
        width = UInt32(dimention.width)
        height = UInt32(dimention.height)
    }
    
    init(_ data: [String: Any]) {
        self.data = data
    }
}

protocol VideoOutputProtocol {
    
    func process(_ data: CMSampleBuffer)
}
