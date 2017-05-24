
import AVFoundation
import VideoToolbox

class TRVideoEncoderH264 : IOVideoOutputProtocol {
    
    private var session: VTCompressionSession?

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Interface
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
        
        let SELF: TRVideoEncoderH264 = unsafeBitCast(outputCallbackRefCon, to: TRVideoEncoderH264.self)
        
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

        let dataSamples:NSMutableData = NSMutableData()
        let dataH264:NSMutableData = NSMutableData()
        
        do {
            // H264 description
            
            let formatDescription: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
            let isKeyframe = !CFDictionaryContainsKey(unsafeBitCast(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), to: CFDictionary.self), unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
            
            if (isKeyframe) {
                let sps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity:  1)
                let pps = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity:  1)
                let spsLength = UnsafeMutablePointer<Int>.allocate(capacity:  1)
                let ppsLength = UnsafeMutablePointer<Int>.allocate(capacity:  1)
                let spsCount = UnsafeMutablePointer<Int>.allocate(capacity:  1)
                let ppsCount = UnsafeMutablePointer<Int>.allocate(capacity:  1)
                
                spsLength.initialize(to: 0)
                ppsLength.initialize(to: 0)
                spsCount.initialize(to: 0)
                ppsCount.initialize(to: 0)
                
                try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                                   0,
                                                                                   sps,
                                                                                   spsLength,
                                                                                   spsCount,
                                                                                   nil),
                                "An Error occured while getting h264 sps parameter")
                
                try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                                   1,
                                                                                   pps,
                                                                                   ppsLength,
                                                                                   ppsCount,
                                                                                   nil),
                                "An Error occured while getting h264 pps parameter")
                
                let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                
                dataSamples.append(naluStart, length: naluStart.count)
                dataSamples.append(sps.pointee!, length: spsLength.pointee)
                dataSamples.append(naluStart, length: naluStart.count)
                dataSamples.append(pps.pointee!, length: ppsLength.pointee)
            }
            
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
            
            var bufferOffset = 0;
            let AVCCHeaderLength = 4
            
            while bufferOffset < totalLength - AVCCHeaderLength {
                var NALUnitLength:UInt32 = 0
                memcpy(&NALUnitLength, dataPointer!.advanced(by: bufferOffset), AVCCHeaderLength)
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                
                let naluStart:[UInt8] = [0x00, 0x00, 0x00, 0x01]
                
                dataH264.append(naluStart, length: naluStart.count)
                dataH264.append(dataPointer!.advanced(by: bufferOffset + AVCCHeaderLength), length: Int(NALUnitLength))
                
                bufferOffset += (AVCCHeaderLength + Int(NALUnitLength))
            }
            
            logNetwork("write video \(dataSamples.length + dataH264.length) bytes")
        }
        catch {
            logIOError(error.localizedDescription)
        }
    }

}
