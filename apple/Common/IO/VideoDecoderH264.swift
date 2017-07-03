
import Foundation
import CoreMedia
import VideoToolbox

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
