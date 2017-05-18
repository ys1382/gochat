import AVFoundation

extension CMFormatDescription {
    func copy() -> CMFormatDescription? {
        let extensions = CMFormatDescriptionGetExtensions(self)
        let mediaType = CMFormatDescriptionGetMediaType(self)
        
        var formatOut: CMFormatDescription?
        var status: OSStatus
        switch mediaType {
        case kCMMediaType_Audio:
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(self)
            status = CMAudioFormatDescriptionCreate(
                nil,
                asbd!,
                0,
                nil,
                0,
                nil,
                extensions,
                &formatOut)
        case kCMMediaType_Video:
            let codecType = CMFormatDescriptionGetMediaSubType(self)
            let dimensions = CMVideoFormatDescriptionGetDimensions(self)
            status = CMVideoFormatDescriptionCreate(
                nil,
                codecType,
                dimensions.width,
                dimensions.height,
                extensions,
                &formatOut)
        default:
            status = noErr
            print("did not handle format description media type \(mediaType)")
        }
        if checkError(status) { return nil }
        return formatOut
    }
}
