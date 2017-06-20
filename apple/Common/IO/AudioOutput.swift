
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AudioOutput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AudioOutput : AudioOutputProtocol, IOSessionProtocol {
    
    private let dqueue: DispatchQueue
    private var squeue: DispatchQueue?
    private var unit: AppleAudioUnit?

    private var buffer = AudioDataReader(capacity: 2)
    private var bufferFrames = 0

    private let formatInput: AudioFormat.Factory
    private var formatDescription: AudioStreamBasicDescription?

    var packets: Int = 0

    init(_ format: @escaping AudioFormat.Factory, _ queue: DispatchQueue) {
        self.dqueue = queue
        self.formatInput = format
    }

    var format: AudioStreamBasicDescription.Factory {
        get {
            return { () in
                return self.formatDescription
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() {
        
        assert(dqueue)
        
        do {
            packets = 0
            squeue = DispatchQueue.CreateCheckable("chat.AudioOutput")
            
            var callback = AURenderCallbackStruct(inputProc: self.callback,
                                                  inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
            
            #if os(iOS)
            unit = try AppleAudioUnit(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO)
            #else
            unit = try AppleAudioUnit(kAudioUnitType_Output, kAudioUnitSubType_VoiceProcessingIO)
            #endif

            try unit!.getFormat(kAudioUnitScope_Input, AudioBus.input, &formatDescription)
            try unit!.setIOEnabled(kAudioUnitScope_Input, AudioBus.output, true)
            try unit!.setRenderer(kAudioUnitScope_Input, AudioBus.input, &callback)
            try unit!.initialize()
            try unit!.start()
        }
        catch {
            logIOError(error)
        }
    }
    
    func stop() {
        
        assert(dqueue)
        
        do {
            try unit!.stop()
            squeue = nil
        }
        catch {
            logIOError(error)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // AudioOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func process(_ data: AudioData) {
        assert(dqueue)
        
        // first few packets plays with artefacts, so skip it
        packets += 1
        guard packets > 10 else { return }
        
        squeue!.sync {
            buffer.push(data)
        }
    }
    
    var lastTime: Double = 0
    
    private let callback: AURenderCallback = {(
        inRefCon: UnsafeMutableRawPointer,
        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        inTimeStamp: UnsafePointer<AudioTimeStamp>,
        inBusNumber: UInt32,
        inNumberFrames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?) in

        let SELF = Unmanaged<AudioOutput>.fromOpaque(inRefCon).takeUnretainedValue()
        let buffers = UnsafeBufferPointer<AudioBuffer>(start: &ioData!.pointee.mBuffers,
                                                       count: Int(ioData!.pointee.mNumberBuffers))

        SELF.squeue!.sync {
            autoreleasepool(invoking: {
                SELF.buffer.pop(Int(inNumberFrames * SELF.formatDescription!.mBytesPerFrame),
                                buffers[0].mData!)
                
                for i in 1 ..< Int(ioData!.pointee.mNumberBuffers) {
                    memcpy(buffers[i].mData!, buffers[0].mData!, Int(buffers[0].mDataByteSize))
                }
            })
        }
        
        return 0
    }
}
