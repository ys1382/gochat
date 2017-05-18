//
//  AVAudioPCMBuffer.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 17/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation

extension AVAudioPCMBuffer {
    
    func serialize() -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: self.floatChannelData, count: channelCount)
        let length = Int(self.frameCapacity * self.format.streamDescription.pointee.mBytesPerFrame)
        
        return NSData(bytes: channels[0], length:length)
    }
    
    static func deserialize(_ data: NSData, _ format: AVAudioFormat) -> AVAudioPCMBuffer {
        assert(UInt32(data.length) % format.streamDescription.pointee.mBytesPerFrame == 0)
        
        let frameCapacity = AVAudioFrameCount(UInt32(data.length) / format.streamDescription.pointee.mBytesPerFrame)
        let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        let channels = UnsafeBufferPointer(start: result.floatChannelData, count: Int(result.frameCapacity))
        
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        result.frameLength = frameCapacity
        
        return result
    }
}
