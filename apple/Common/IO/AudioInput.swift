
import AudioToolbox
import AVFoundation

class AudioInput : NSObject, IOSessionProtocol
{
    private var audioFormat: AudioFormat?

    private var queue: AudioQueueRef?
    private var	buffer: AudioQueueBufferRef?

    private let output: AudioOutputProtocol?
    private let formatID: UInt32
    private let interval: Double
    
    public var format: AudioFormat.Factory {
        get {
            return { () in self.audioFormat! }
        }
    }

    init(_ formatID: UInt32, _ interval: Double, _ output: AudioOutputProtocol?) {
        self.output = output
        self.formatID = formatID
        self.interval = interval
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() throws {
        assert_av_capture_queue()
        
        // prepare format

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode!.inputFormat(forBus: AudioBus.input)
        var format = AudioStreamBasicDescription.CreateInput(formatID,
                                                             8000/*inputFormat.sampleRate*/,
            1/*inputFormat.channelCount*/)
        var packetMaxSize: UInt32 = 0
        
        // start queue
        
        var bufferByteSize: UInt32
        var size: UInt32

        // create the queue
        
        try checkStatus(AudioQueueNewInput(
            &format,
            callback,
            Unmanaged.passUnretained(self).toOpaque() /* userData */,
            CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue,
            0 /* flags */,
            &queue), "AudioQueueNewInput failed")
        
        
        // get the record format back from the queue's audio converter --
        // the file may require a more specific stream description than was necessary to create the encoder.
        
        size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkStatus(AudioQueueGetProperty(queue!,
                                              kAudioQueueProperty_StreamDescription,
                                              &format,
                                              &size), "couldn't get queue's format");
        
        // allocate and enqueue buffers
        
        bufferByteSize = computeBufferSize(format,
                                           interval,
                                           &packetMaxSize);	// enough bytes for kBufferDurationSeconds
        
        try checkStatus(AudioQueueAllocateBuffer(queue!,
                                                 bufferByteSize,
                                                 &buffer), "AudioQueueAllocateBuffer failed");
        
        try checkStatus(AudioQueueEnqueueBuffer(queue!,
                                                buffer!,
                                                0,
                                                nil), "AudioQueueEnqueueBuffer failed");
        
        // start the queue
        
        try checkStatus(AudioQueueStart(queue!,
                                        nil), "AudioQueueStart failed");
        
        // audio format
        
        audioFormat = AudioFormat(format, packetMaxSize)
    }
    
    func stop() {
        assert_av_capture_queue()

        guard let queue = self.queue else { assert(false); return }

        do {
            // end recording
            try checkStatus(AudioQueueStop(queue,
                                           true), "AudioQueueStop failed")
            
            // a codec may update its cookie at the end of an encoding session, so reapply it to the file now
            try checkStatus(AudioQueueDispose(queue,
                                              true), "AudioQueueDispose failed")
            
            self.queue = nil
        }
        catch {
            logIOError(error)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Utils
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func computeBufferSize(_ format: AudioStreamBasicDescription,
                           _ interval: Double,
                           _ packetMaxSize: inout UInt32) -> UInt32
    {
        var packets: UInt32
        var frames: UInt32
        var bytes: UInt32 = 0
        
        do {
            frames = UInt32(ceil(interval * format.mSampleRate))
            
            if (format.mBytesPerFrame > 0) {
                bytes = frames * format.mBytesPerFrame
                packetMaxSize = format.mBytesPerPacket
            }
            else {
                if (format.mBytesPerPacket > 0) {
                    packetMaxSize = format.mBytesPerPacket	// constant packet size
                }
                else {
                    var propertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
                    try checkStatus(AudioQueueGetProperty(queue!,
                                                          kAudioQueueProperty_MaximumOutputPacketSize,
                                                          &packetMaxSize,
                                                          &propertySize),
                                    "couldn't get queue's maximum output packet size")
                }
                
                if (format.mFramesPerPacket > 0) {
                    packets = frames / format.mFramesPerPacket
                }
                else {
                    packets = frames	// worst-case scenario: 1 frame in a packet
                }

                if (packets == 0) {		// sanity check
                    packets = 1
                }
                
                bytes = packets * packetMaxSize;
            }
        }
        catch {
            logIOError(error)
        }
        
        return bytes;
    }

    private let callback: AudioQueueInputCallback = {
        (inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer: AudioQueueBufferRef,
        inStartTime: UnsafePointer<AudioTimeStamp>,
        inNumPackets: UInt32,
        inPacketDesc: UnsafePointer<AudioStreamPacketDescription>?) in
        
        let input = Unmanaged<AudioInput>.fromOpaque(inUserData!).takeUnretainedValue()
        
        logIO("audio \(AVAudioTime.seconds(forHostTime: inStartTime.pointee.mHostTime))")
        
        
        do {
            if (inNumPackets > 0) {
                var bytes = UnsafeMutablePointer<Int8>.allocate(capacity: Int(inBuffer.pointee.mAudioDataByteSize))
                
                memcpy(bytes, inBuffer.pointee.mAudioData, Int(inBuffer.pointee.mAudioDataByteSize))
                
                input.output!.process(AudioData(bytes,
                                                  inBuffer.pointee.mAudioDataByteSize,
                                                  inPacketDesc!,
                                                  inNumPackets,
                                                  inStartTime))
            }
            
            try checkStatus(AudioQueueEnqueueBuffer(input.queue!,
                                                    input.buffer!,
                                                    0,
                                                    nil), "AudioQueueEnqueueBuffer failed");
        }
        catch {
            logIOError(error)
        }
    }
}
