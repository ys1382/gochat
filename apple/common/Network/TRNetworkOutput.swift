//
//  TRNetworkOutput.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 24/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AudioToolbox

class TRNetworkOutput : TRAudioOutputProtocol {
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TRAudioOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func start(_ format: UnsafePointer<AudioStreamBasicDescription>,
               _ maxPacketSize: UInt32,
               _ interval: Double) {
        
        // TODO: setup audio session
    }
    
    func stop() {
        
    }
    
    func process(_ buffer: AudioQueueBufferRef,
                 _ packetDesc: UnsafePointer<AudioStreamPacketDescription>,
                 _ packetNum: UInt32,
                 _ timeStamp: UnsafePointer<AudioTimeStamp>) {
        
        // TODO: serialize:
        // 1. AudioQueueBufferRef.mAudioDataByteSize
        // 2. AudioQueueBufferRef.mAudioData
        // 3. packet descriptions number
        // 4. packet descriptions
        // 5. timestamp
        
        
        var size: UInt32 = 0
        
        size += UInt32(buffer.pointee.mAudioDataByteSize)
        size += UInt32(MemoryLayout<UInt32>.size)
        size += UInt32(MemoryLayout<AudioStreamPacketDescription>.size) * packetNum
        size += UInt32(MemoryLayout<UInt32>.size)
        size += UInt32(MemoryLayout<AudioTimeStamp>.size)
        
        logNetwork("write audio \(size) bytes")
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

}
