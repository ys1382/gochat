
import CoreMedia

extension CMSampleTimingInfo {
    
    init(_ data: NSData) {
        self.init()
        memcpy(&self, data.bytes, MemoryLayout<CMSampleTimingInfo>.size)
    }
    
    func toNSData() -> NSData {
        var copy = self
        return NSData(bytes: &copy, length: MemoryLayout<CMSampleTimingInfo>.size)
    }
}

extension CMVideoDimensions : Equatable {
    
    public static func ==(lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }

    
    func turn() -> CMVideoDimensions {
        return CMVideoDimensions(width: height, height: width)
    }
    
    func bitrate() -> Int32 {
        return width * height
    }
    
}

func CMTimeSetSeconds(_ time: inout CMTime, _ seconds: Float64) {
    time.value = CMTimeValue(seconds * Float64(time.timescale))
}
