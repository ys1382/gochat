//
//  CMSampleBuffer.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation

extension CMSampleBuffer {
    func copy() -> CMSampleBuffer? {
        
        let formatDescription = CMSampleBufferGetFormatDescription(self)!
        guard let formatDescriptionOut = formatDescription.copy() else {
            return nil
        }
        
        var count: CMItemCount = 1
        var timingInfoIn = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(self, count, &timingInfoIn, &count)
        let timingInfoOut = timingInfoIn.copy()
        
        switch CMFormatDescriptionGetMediaType(formatDescription) {
        case kCMMediaType_Audio:
            return audioCopy(format: formatDescriptionOut, timing: timingInfoOut)
        case kCMMediaType_Video:
            return videoCopy(format: formatDescriptionOut, timing: timingInfoOut)
        default:
            print("did not handle format description type \(CMFormatDescriptionGetMediaType(formatDescription))")
            return nil
        }
    }
    
    func getMediaType() -> CMMediaType? {
        if let formatDescription = CMSampleBufferGetFormatDescription(self) {
            return CMFormatDescriptionGetMediaType(formatDescription)
        }
        return nil
    }
    
    func getAudioListAndBlockBuffer() -> (status: OSStatus,
        audioBufferList: UnsafeMutableAudioBufferListPointer?,
        blockBuffer: CMBlockBuffer?) {
            
            var bufferListSizeNeededOut: Int = 0
            var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                self,
                &bufferListSizeNeededOut,
                nil,
                0,
                nil,
                nil,
                kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                nil
            )
            if checkError(status) { return (status, nil, nil) }
            
            let formatDescription = CMSampleBufferGetFormatDescription(self)!
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)!.pointee
            let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(asbd.mChannelsPerFrame))
            
            var blockBuffer: CMBlockBuffer?
            status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                self,
                nil,
                &audioBufferList.unsafeMutablePointer.pointee,
                bufferListSizeNeededOut,
                nil,
                nil,
                kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                &blockBuffer
            )
            if checkError(status) { return (status, nil, nil) }
            
            return (status, audioBufferList, blockBuffer)
    }
    
    func audioCopy(format: CMFormatDescription, timing: CMSampleTimingInfo) -> CMSampleBuffer? {
        
        let (status1, _, blockBuffer) = self.getAudioListAndBlockBuffer()
        if checkError(status1) { return nil }
        
        // clone audio CMSampleBuffer
        var sampleBufferOut: CMSampleBuffer?
        var timingInfo = timing
        let numSamples = CMSampleBufferGetNumSamples(self)
        
        let status2 = CMSampleBufferCreateReady(
            kCFAllocatorDefault,
            blockBuffer,
            format,
            numSamples,
            1,
            &timingInfo,
            0,
            nil,
            &sampleBufferOut)
        if checkError(status2) { return nil }
        
        return sampleBufferOut
    }
    
    func videoCopy(format: CMFormatDescription, timing: CMSampleTimingInfo) -> CMSampleBuffer? {
        guard let pixelBufferIn : CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("could not get image buffer")
            return nil
        }
        let pixelBufferOut = pixelBufferIn.copy()
        
        var timingInfo = timing
        var sampleBufferOut: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            pixelBufferOut,
            format,
            &timingInfo,
            &sampleBufferOut)
        
        if checkError(status) { return nil }
        return sampleBufferOut
    }
}
