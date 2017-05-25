
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOAudioOutputProtocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRNetworkAudioOutput : IOAudioOutputProtocol {
    
    
    func start(_ format: UnsafePointer<AudioStreamBasicDescription>,
               _ maxPacketSize: UInt32,
               _ interval: Double) {
        
        // TODO: setup audio session
    }
    
    func stop() {
        
    }
    
    func process(_ data: IOAudioData) {
        
        // TODO: serialize:
        // 1. AudioQueueBufferRef.mAudioDataByteSize
        // 2. AudioQueueBufferRef.mAudioData
        // 3. packet descriptions number
        // 4. packet descriptions
        // 5. timestamp
        
        
        var size: UInt32 = 0
        
        size += UInt32(data.bytesNum)
        size += UInt32(MemoryLayout<UInt32>.size)
        size += UInt32(MemoryLayout<AudioStreamPacketDescription>.size) * data.packetNum
        size += UInt32(MemoryLayout<UInt32>.size)
        size += UInt32(MemoryLayout<AudioTimeStamp>.size)
        
        logNetwork("write audio \(size) bytes")
    }
}

