
import CoreAudio

extension AudioStreamBasicDescription {
    
    static func CreateInput(_ formatID: UInt32,
                            _ sampleRate: Double,
                            _ channelCount: UInt32) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription()
        
        result.mSampleRate = sampleRate;
        result.mChannelsPerFrame = channelCount;
        result.mFormatID = formatID;
        
        if (formatID == kAudioFormatLinearPCM)
        {
            // if we want pcm, default to signed 16-bit little-endian
            result.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
            result.mBitsPerChannel = 16;
            result.mBytesPerFrame = (result.mBitsPerChannel / 8) * result.mChannelsPerFrame;
            result.mBytesPerPacket = result.mBytesPerFrame
            result.mFramesPerPacket = 1;
        }
        
        return result
    }
    
    static func CreateOutput(_ format: AudioFormat,
                             _ formatID: UInt32) -> AudioStreamBasicDescription {
        var result = AudioStreamBasicDescription.CreateInput(formatID, format.sampleRate, format.channelCount)
        
        result.mFormatFlags = format.flags
        result.mFramesPerPacket = format.framesPerPacket
        
        return result
    }
}

extension AudioTimeStamp {
    
    func seconds() -> Double {
        return Double(mHostTime) / 1000000000.0
    }

    mutating func seconds(_ x: Double) {
        mHostTime = UInt64(x * 1000000000.0)
    }
}
