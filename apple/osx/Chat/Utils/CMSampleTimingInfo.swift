import AVFoundation

extension CMSampleTimingInfo {
    func copy() -> CMSampleTimingInfo {
        let durationIn = self.duration
        let presentationIn = self.presentationTimeStamp
        let decodeIn = kCMTimeInvalid
        return CMSampleTimingInfo(duration: durationIn, presentationTimeStamp: presentationIn, decodeTimeStamp: decodeIn)
    }
}
