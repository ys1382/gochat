
import CoreMedia

extension CMSampleTimingInfo {
    
    init(_ data: NSData) {
        let cmTimeSize = MemoryLayout<CMTime>.size
        let d0 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: 0 * cmTimeSize)),
                        length: cmTimeSize,
                        freeWhenDone: false)
        let d1 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: 1 * cmTimeSize)),
                        length: cmTimeSize,
                        freeWhenDone: false)
        let d2 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: 2 * cmTimeSize)),
                        length: cmTimeSize,
                        freeWhenDone: false)
        
        duration = CMTime(d0)
        presentationTimeStamp = CMTime(d1)
        decodeTimeStamp = CMTime(d2)
    }
    
    func toNSData() -> NSData {
        let result = NSMutableData()
        
        result.append(duration.toNSData() as Data)
        result.append(presentationTimeStamp.toNSData() as Data)
        result.append(decodeTimeStamp.toNSData() as Data)
        
        return result
    }
}

extension CMTime {
    
    init(_ data: NSData) {
        self.init()
        
        CMTime.assertTypes()
        
        let s0 = MemoryLayout<CMTimeValue>.size
        let s1 = MemoryLayout<CMTimeScale>.size
        let s2 = MemoryLayout<CMTimeFlags>.size
        let s3 = MemoryLayout<CMTimeEpoch>.size
        var shift = 0
        
        let d0 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: shift)),
                        length: s0,
                        freeWhenDone: false)
        shift += s0
        let d1 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: shift)),
                        length: s1,
                        freeWhenDone: false)
        shift += s1
        let d2 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: shift)),
                        length: s2,
                        freeWhenDone: false)
        shift += s2
        let d3 = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: shift)),
                        length: s3,
                        freeWhenDone: false)
        
        memcpy(&value,     d0.bytes, s0)
        memcpy(&timescale, d1.bytes, s1)
        memcpy(&flags,     d2.bytes, s2)
        memcpy(&epoch,     d3.bytes, s3)
    }
    
    func toNSData() -> NSData {
        CMTime.assertTypes()
        
        let result = NSMutableData()
        var copy = self
        
        result.append(&copy.value, length: MemoryLayout<CMTimeValue>.size)
        result.append(&copy.timescale, length: MemoryLayout<CMTimeScale>.size)
        result.append(&copy.flags, length: MemoryLayout<CMTimeFlags>.size)
        result.append(&copy.epoch, length: MemoryLayout<CMTimeEpoch>.size)
        
        return result
    }
    
    private static func assertTypes() {
        assert(MemoryLayout<CMTimeValue>.size == MemoryLayout<Int64>.size)
        assert(MemoryLayout<CMTimeScale>.size == MemoryLayout<Int32>.size)
        assert(MemoryLayout<CMTimeFlags>.size == MemoryLayout<UInt32>.size)
        assert(MemoryLayout<CMTimeEpoch>.size == MemoryLayout<Int64>.size)
    }
}
