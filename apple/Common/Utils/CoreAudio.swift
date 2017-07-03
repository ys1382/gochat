
import CoreAudio

extension AudioStreamBasicDescription {

    typealias Factory = () throws -> AudioStreamBasicDescription?
    
    // constant bit rate
    static func CreateCBR(_ formatID: UInt32,
                          _ sampleRate: Double,
                          _ channelCount: UInt32) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription()
        
        result.mSampleRate = sampleRate;
        result.mChannelsPerFrame = channelCount;
        result.mFormatID = formatID;
        
        // if we want pcm, default to signed 16-bit little-endian
        result.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        result.mBitsPerChannel = 16;
        result.mBytesPerFrame = (result.mBitsPerChannel / 8) * result.mChannelsPerFrame
        result.mBytesPerPacket = result.mBytesPerFrame
        result.mFramesPerPacket = 1;
        
        return result
    }

    // constant bit rate
    static func CreateCBR(_ format: AudioFormat) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription.CreateCBR(format.formatID, format.sampleRate, format.channelCount)
        
        result.mFormatFlags = format.flags
        result.mFramesPerPacket = format.framesPerPacket
        
        return result
    }

    // variable bit rate
    static func CreateVBR(_ formatID: UInt32,
                          _ sampleRate: Double,
                          _ channelCount: UInt32) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription()
        
        result.mSampleRate = sampleRate
        result.mChannelsPerFrame = channelCount
        result.mFormatID = formatID
        
        return result
    }
    
    // variable bit rate
    static func CreateVBR(_ format: AudioFormat) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription.CreateVBR(format.formatID, format.sampleRate, format.channelCount)
        
        result.mFormatFlags = format.flags
        result.mFramesPerPacket = format.framesPerPacket
        
        return result
    }
}

extension AudioTimeStamp {
    
    func seconds() -> Double {
        return mach_absolute_seconds(mHostTime)
    }

    mutating func seconds(_ x: Double) {
        mHostTime = mach_absolute_time(seconds: x)
    }
}

extension AudioStreamPacketDescription : InitProtocol {
    
    static func ToArray(_ ptr: UnsafePointer<AudioStreamPacketDescription>,
                        _ num: UInt32) -> [AudioStreamPacketDescription] {
        var result = [AudioStreamPacketDescription]()
        
        for i in 0 ..< num {
            result.append(ptr.advanced(by: Int(i)).pointee)
        }
        
        return result
    }
}
