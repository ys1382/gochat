
import AVFoundation
import VideoToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Encoder
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoEncoderH264 : NSObject, VideoOutputProtocol {
    
    private let output: IODataProtocol?
    
    init(_ output: IODataProtocol) {
        
        self.output = output

        super.init()
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func process(_ data: CMSampleBuffer) {
        encode(data)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Encode to H264
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    private func encode(_ sampleBuffer: CMSampleBuffer) {

        var result = [Int: NSData]()
        
        do {
            let formatDescription: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!

            assert(CMSampleBufferGetNumSamples(sampleBuffer) == 1)

            // timing info
            
            let timingInfo = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: 1)
            
            try checkStatus(CMSampleBufferGetSampleTimingInfo(sampleBuffer,
                                                              0,
                                                              timingInfo),
                            "CMSampleBufferGetSampleTimingInfo failed")

            result[H264Part.Time.rawValue] = timingInfo.pointee.toNSData()
            
            // H264 description (SPS)
            
            let sps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity:  1)
            let spsLength = UnsafeMutablePointer<Int>.allocate(capacity:  1)
            let count = UnsafeMutablePointer<Int>.allocate(capacity:  1)
            
            try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                               0,
                                                                               sps,
                                                                               spsLength,
                                                                               count,
                                                                               nil),
                            "An Error occured while getting h264 sps parameter")
            
            assert(count.pointee == 2) // sps and pps
            
            result[H264Part.SPS.rawValue] = NSData(bytes: sps.pointee!, length: spsLength.pointee)
           
            // H264 description (PPS)

            let pps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity:  1)
            let ppsLength = UnsafeMutablePointer<Int>.allocate(capacity:  1)

            try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                               1,
                                                                               pps,
                                                                               ppsLength,
                                                                               count,
                                                                               nil),
                            "An Error occured while getting h264 pps parameter")

            assert(count.pointee == 2) // sps and pps

            result[H264Part.PPS.rawValue] = NSData(bytes: pps.pointee!, length: ppsLength.pointee)

            // H264 data
            
            let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
            var totalLength = Int()
            var length = Int()
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            
            try checkStatus(CMBlockBufferGetDataPointer(blockBuffer!,
                                                        0,
                                                        &length,
                                                        &totalLength,
                                                        &dataPointer), "CMBlockBufferGetDataPointer failed")
            
            assert(length == totalLength)
            
            result[H264Part.Data.rawValue] = NSData(bytes: dataPointer!, length: Int(totalLength))

            // output
            
            AV.shared.videoCaptureQueue.async { self.output?.process(result) }
        }
        catch {
            logIOError(error)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Session
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoEncoderSessionH264 : VideoSessionProtocol, VideoOutputProtocol {
    
    public typealias Callback = (VideoEncoderSessionH264) -> Void
    
    private var session: VTCompressionSession?
    private let inputDimension: CMVideoDimensions
    private var outputFormat: VideoFormat
    private let next: VideoOutputProtocol?
    private let callback: Callback?

    init(_ inputDimension: CMVideoDimensions,
         _ outputFormat: VideoFormat,
         _ next: VideoOutputProtocol?) {
        self.inputDimension = inputDimension
        self.outputFormat = outputFormat
        self.next = next
        self.callback = nil
    }

    init(_ inputDimension: CMVideoDimensions,
         _ outputFormat: VideoFormat,
         _ next: VideoOutputProtocol?,
         _ callback: @escaping Callback) {
        self.inputDimension = inputDimension
        self.outputFormat = outputFormat
        self.next = next
        self.callback = callback
    }

    private var sessionCallback: VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer_:CMSampleBuffer?
        ) in

        let SELF: VideoEncoderSessionH264 = unsafeBitCast(outputCallbackRefCon, to: VideoEncoderSessionH264.self)
        guard let sampleBuffer = sampleBuffer_ else { logIOError("VideoEncoderSessionH264 nil buffer"); return }
        
        do {
            try checkStatus(status, "VTCompressionSession to H264 failed")
            
            AV.shared.videoCaptureQueue.async {
                SELF.callback?(SELF)
                SELF.next?.process(sampleBuffer)
            }
        }
        catch {
            logIOError(error)
        }
        
    } as VTCompressionOutputCallback

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() throws {
        assert_video_capture_queue()

        VTCompressionSessionCreate(
            kCFAllocatorDefault,
            Int32(outputFormat.width),
            Int32(outputFormat.height),
            kCMVideoCodecType_H264,
            nil,
            attributes as CFDictionary,
            nil,
            sessionCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            &session)
        
        VTSessionSetProperties(session!, properties as CFDictionary)
        VTCompressionSessionPrepareToEncodeFrames(session!)
    }

    func stop() {
        assert_video_capture_queue()
        
        guard let session = self.session else { return }
        
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid)
        VTCompressionSessionInvalidate(session)
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func update(_ outputFormat: VideoFormat) throws {
        self.outputFormat = outputFormat
        
        stop()
        try start()
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func process(_ data: CMSampleBuffer) {
        guard let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(data) else { return }
        guard let session = self.session else { logIOError("VideoEncoderSessionH264 no session"); return }
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        
        VTCompressionSessionEncodeFrame(session,
                                        imageBuffer,
                                        CMSampleBufferGetPresentationTimeStamp(data),
                                        CMSampleBufferGetDuration(data),
                                        nil,
                                        nil,
                                        &flags)
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Settings
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject,
        ]
    fileprivate var width:Int32!
    fileprivate var height:Int32!
    
    fileprivate var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = defaultAttributes
        attributes[kCVPixelBufferHeightKey] = inputDimension.height as AnyObject
        attributes[kCVPixelBufferWidthKey] = inputDimension.width as AnyObject
        return attributes
    }
    
    var profileLevel:String = kVTProfileLevel_H264_Baseline_AutoLevel as String
    fileprivate var properties:[NSString: AnyObject] {
        let isBaseline:Bool = profileLevel.contains("Baseline")
        var properties:[NSString: AnyObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel as NSObject,
            kVTCompressionPropertyKey_AverageBitRate: Int(outputFormat.width * outputFormat.height) as NSObject,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: 1.0 as Double),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline as NSObject,
        ]
        if (!isBaseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }
}

