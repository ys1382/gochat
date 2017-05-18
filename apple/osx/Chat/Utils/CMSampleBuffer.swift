import AVFoundation

extension CMSampleBuffer {
    func copy() -> CMSampleBuffer? {
        
        let formatDescriptionIn = CMSampleBufferGetFormatDescription(self)!
        guard let formatDescriptionOut = formatDescriptionIn.copy() else {
            return nil
        }
        
        var count: CMItemCount = 1
        var timingInfoIn = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(self, count, &timingInfoIn, &count)
        var timingInfoOut = timingInfoIn.copy()
        
        if CMFormatDescriptionGetMediaType(formatDescriptionOut) != kCMMediaType_Video {
            print("did not handle format description type \(CMFormatDescriptionGetMediaType(formatDescriptionOut))")
            return nil
        }

        guard let pixelBufferIn : CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("could not get image buffer")
            return nil
        }
        let pixelBufferOut = pixelBufferIn.copy()

        var sampleBufferOut: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            pixelBufferOut,
            formatDescriptionOut,
            &timingInfoOut,
            &sampleBufferOut)

        if checkError(status) { return nil }
        return sampleBufferOut
    }
}
