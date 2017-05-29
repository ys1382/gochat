
import Foundation
import CoreMedia

class VideoDecoderH264 : DataProtocol {
    
    private let output: VideoOutputProtocol?
    private var formatDescription : CMFormatDescription?

    init(_ output: VideoOutputProtocol?) {
        self.output = output
    }
    
    func process(_ data: [Int: NSData]) {
        
        let h264SPS  = data[H264Part.SPS.rawValue]!
        let h264PPS  = data[H264Part.PPS.rawValue]!
        let h264Data = data[H264Part.Data.rawValue]!
        let h264Time = data[H264Part.Time.rawValue]!

        do {
            // format description
            
            var formatDescription: CMFormatDescription?
            
            let parameterSetPointers : [UnsafePointer<UInt8>] = [h264SPS.bytes.assumingMemoryBound(to: UInt8.self),
                                                                 h264PPS.bytes.assumingMemoryBound(to: UInt8.self)]
            let parameterSetSizes : [Int] = [h264SPS.length,
                                             h264PPS.length]
            
            try checkStatus(CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                                2,
                                                                                parameterSetPointers,
                                                                                parameterSetSizes,
                                                                                4,
                                                                                &formatDescription),
                            "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            
            // block buffer
            
            var blockBuffer: CMBlockBuffer?
            let blockBufferData = UnsafeMutablePointer<Int8>.allocate(capacity: h264Data.length)
            blockBufferData.assign(from: h264Data.bytes.assumingMemoryBound(to: Int8.self), count: h264Data.length)

            try checkStatus(CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                               blockBufferData,
                                                               h264Data.length,
                                                               kCFAllocatorDefault,
                                                               nil,
                                                               0,
                                                               h264Data.length,
                                                               0,
                                                               &blockBuffer), "createReadonlyBlockBuffer")
            
            // timing info
            
            let timingInfo = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: 1)
            timingInfo[0] = CMSampleTimingInfo(h264Time)

            // sample buffer
            
            var sampleBuffer : CMSampleBuffer?
            try checkStatus(CMSampleBufferCreateReady(kCFAllocatorDefault,
                                                      blockBuffer,
                                                      formatDescription,
                                                      1,
                                                      1,
                                                      timingInfo,
                                                      0,
                                                      nil,
                                                      &sampleBuffer), "CMSampleBufferCreateReady failed")
            
            // output
            
            output?.process(sampleBuffer!)
        }
        catch {
            logIOError(error)
        }
    }
    
}
