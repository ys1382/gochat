
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

extension CMVideoDimensions {
    
    func turn() -> CMVideoDimensions {
        return CMVideoDimensions(width: height, height: width)
    }
    
    func bitrate() -> Int32 {
        return width * height
    }
    
}
