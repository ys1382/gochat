
import Foundation
import CoreMedia
import VideoToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoDecoderH264Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoDecoderH264Data : IODataProtocol, IOSyncedDataProtocol {
    
    private let output: VideoOutputProtocol?

    init(_ output: VideoOutputProtocol?) {
        self.output = output
    }
    
    func tuning(_ data: [Int : NSData]) {
        process(data)
    }
    
    func belated(_ data: [Int : NSData]) {
        process(data)
    }
    
    func process(_ data: [Int: NSData]) {
        
        let h264SPS  = data[H264Part.SPS.rawValue]!
        let h264PPS  = data[H264Part.PPS.rawValue]!
        let h264Data = data[H264Part.Data.rawValue]!
        let h264Time = data[IOPart.Timestamp.rawValue]!

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
            
            var timingInfo = VideoTime(deserialize: h264Time).ToCMSampleTimingInfo()

            // sample buffer
            
            var sampleBuffer : CMSampleBuffer?
            try checkStatus(CMSampleBufferCreateReady(kCFAllocatorDefault,
                                                      blockBuffer,
                                                      formatDescription,
                                                      1,
                                                      1,
                                                      &timingInfo,
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoDecoderH264
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoDecoderH264 : VideoOutputProtocol, VideoSessionProtocol {
    
    private let next: VideoOutputProtocol?
    private var session: VTDecompressionSession?
    
    init(_ next: VideoOutputProtocol?) {
        self.next = next
    }
    
    func start() throws {
    }
    
    func stop() {
        
    }
    
    func update(_ outputFormat: VideoFormat) throws {
        
    }
    
    func process(_ data: CMSampleBuffer) {
        if session == nil {
            do {
                guard
                    let formatDescription = CMSampleBufferGetFormatDescription(data)
                    else { logError("CMSampleBufferGetFormatDescription"); return }
                let destinationPixelBufferAttributes = NSMutableDictionary()
                destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_32BGRA), forKey: kCVPixelBufferPixelFormatTypeKey as String)
                
                var outputCallback = VTDecompressionOutputCallbackRecord()
                outputCallback.decompressionOutputCallback = callback
                outputCallback.decompressionOutputRefCon = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
                
                try checkStatus(VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                             formatDescription,
                                                             nil,
                                                             destinationPixelBufferAttributes,
                                                             &outputCallback,
                                                             &session), "VTDecompressionSessionCreate")
            }
            catch {
                logIOError(error)
            }
        }
        
        var infoFlags = VTDecodeInfoFlags(rawValue: 0)
        
        VTDecompressionSessionDecodeFrame(session!,
                                          data,
                                          [._1xRealTimePlayback],
                                          nil,
                                          &infoFlags)
        VTDecompressionSessionFinishDelayedFrames(session!)
        VTDecompressionSessionWaitForAsynchronousFrames(session!)
    }
    
    var i = 0
    
    private var callback: VTDecompressionOutputCallback = {(decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVImageBuffer?,
        presentationTimeStamp: CMTime,
        presentationDuration: CMTime) in
        
        do {
            try checkStatus(status, "VTDecompressionOutputCallbacks")
            
            let SELF: VideoDecoderH264 = unsafeBitCast(decompressionOutputRefCon, to: VideoDecoderH264.self)
            var sampleBuffer: CMSampleBuffer?
            
            var sampleTiming = CMSampleTimingInfo(
                duration: presentationDuration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: kCMTimeInvalid
            )
            
            var formatDescription: CMFormatDescription?
            
            try checkStatus(CMVideoFormatDescriptionCreateForImageBuffer(
                kCFAllocatorDefault,
                imageBuffer!,
                &formatDescription), "CMVideoFormatDescriptionCreateForImageBuffer")
            
            
            try checkStatus(CMSampleBufferCreateForImageBuffer(
                kCFAllocatorDefault,
                imageBuffer!,
                true,
                nil,
                nil,
                formatDescription!,
                &sampleTiming,
                &sampleBuffer), "CMSampleBufferCreateForImageBuffer")
            
            AV.shared.avOutputQueue.async {
                SELF.next?.process(sampleBuffer!)
            }
        }
        catch {
            logIOError(error)
        }
        
        } as VTDecompressionOutputCallback
}
