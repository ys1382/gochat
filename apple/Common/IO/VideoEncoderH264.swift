
import AVFoundation
import VideoToolbox

class VideoEncoderH264 : VideoOutputProtocol {
    
    private var session: VTCompressionSession?
    private var output: DataProtocol?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Interface
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    init(_ output: DataProtocol) {
        self.output = output
        
        start()
    }
    
    func start() {
        
        VTCompressionSessionCreate(
            kCFAllocatorDefault,
            720, // encode height
            1280,// encode width
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
    
    func process(_ data: CMSampleBuffer) {
        
        guard let image:CVImageBuffer = CMSampleBufferGetImageBuffer(data) else {
            return
        }
        
        encodeImageBuffer(image,
                          CMSampleBufferGetPresentationTimeStamp(data),
                          CMSampleBufferGetDuration(data))
    }
    
    func stop() {
        VTCompressionSessionInvalidate(session!)
        session = nil
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Encoder session
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    fileprivate var sessionCallback:VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?
        ) in
        
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer, status == noErr else {
            return
        }
        
        let SELF: VideoEncoderH264 = unsafeBitCast(outputCallbackRefCon, to: VideoEncoderH264.self)
        
        SELF.encodeSampleBuffer(sampleBuffer)
    } as VTCompressionOutputCallback
    
    let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) as AnyObject,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLCompatibilityKey: true as AnyObject,
        ]
    fileprivate var width:Int32!
    fileprivate var height:Int32!
    
    fileprivate var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = defaultAttributes
        attributes[kCVPixelBufferHeightKey] = 720 as AnyObject
        attributes[kCVPixelBufferWidthKey] = 1280 as AnyObject
        return attributes
    }
    
    var profileLevel:String = kVTProfileLevel_H264_Baseline_3_1 as String
    fileprivate var properties:[NSString: AnyObject] {
        let isBaseline:Bool = profileLevel.contains("Baseline")
        var properties:[NSString: AnyObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel as NSObject,
            kVTCompressionPropertyKey_AverageBitRate: Int(1280*720) as NSObject,
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: 30.0 as Double),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: 2.0 as Double),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline as NSObject,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
                ] as AnyObject
        ]
        if (!isBaseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Encode to H264
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    private func encodeImageBuffer(_ imageBuffer:CVImageBuffer,
                                   _ presentationTimeStamp:CMTime,
                                   _ presentationDuration:CMTime) {
        
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        
        VTCompressionSessionEncodeFrame(session!,
                                        imageBuffer,
                                        presentationTimeStamp,
                                        presentationDuration,
                                        nil,
                                        nil,
                                        &flags)
    }
    
    private func encodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {

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
            
            output?.process(result)
        }
        catch {
            logIOError(error)
        }
    }
}
