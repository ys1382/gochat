
import AudioToolbox
import AVFoundation

class AudioInput : NSObject, IOSessionProtocol
{
    private static let kBuffersCount = 3

    public var output: AudioOutputProtocol?

    private var queue: AudioQueueRef?
    private var	buffers = [AudioQueueBufferRef]()
    private var stopping: Bool = false

    private var formatDescription: AudioStreamBasicDescription
    private var formatChat: AudioFormat?
    private let interval: Double
    
    private var thread: ChatThread?
    private let dqueue: DispatchQueue

    public var format: AudioFormat.Factory {
        get {
            return { () in self.formatChat! }
        }
    }

    init(_ format: AudioStreamBasicDescription,
         _ interval: Double,
         _ queue: DispatchQueue,
         _ output: AudioOutputProtocol?) {
        self.formatDescription = format
        self.interval = interval
        self.dqueue = queue
        self.output = output
    }

    convenience init(_ format: AudioStreamBasicDescription,
                     _ interval: Double,
                     _ output: AudioOutputProtocol?) {
        self.init(format, interval, AV.shared.audioCaptureQueue, output)
    }

    convenience init(_ format: AudioStreamBasicDescription,
                     _ interval: Double) {
        self.init(format, interval, nil)
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func start() throws {
        assert(dqueue)

        // thread
        
        thread = ChatThread(AudioInput.self)
        thread!.start()

        // start queue
        
        var packetMaxSize: UInt32 = 0
        var bufferByteSize: UInt32
        var size: UInt32

        // create the queue
        
        try checkStatus(AudioQueueNewInput(
            &formatDescription,
            callback,
            Unmanaged.passUnretained(self).toOpaque() /* userData */,
            thread!.runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue,
            0 /* flags */,
            &queue), "AudioQueueNewInput failed")
        
        // get the record format back from the queue's audio converter --
        // the file may require a more specific stream description than was necessary to create the encoder.
        
        size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkStatus(AudioQueueGetProperty(queue!,
                                              kAudioQueueProperty_StreamDescription,
                                              &formatDescription,
                                              &size), "couldn't get queue's format");
        
        // allocate and enqueue buffers
        
        bufferByteSize = computeBufferSize(formatDescription,
                                           interval,
                                           &packetMaxSize);	// enough bytes for kBufferDurationSeconds

        for _ in 0 ..< AudioInput.kBuffersCount {
            var buffer: AudioQueueBufferRef?
            
            try checkStatus(AudioQueueAllocateBuffer(queue!,
                                                     bufferByteSize,
                                                     &buffer), "AudioQueueAllocateBuffer failed");

            try checkStatus(AudioQueueEnqueueBuffer(queue!,
                                                    buffer!,
                                                    0,
                                                    nil), "AudioQueueEnqueueBuffer failed");
        }
        
        // start the queue
        
        try checkStatus(AudioQueueStart(queue!,
                                        nil), "AudioQueueStart failed");
        
        // audio format
        
        formatChat = AudioFormat(formatDescription)
    }
    
    func stop() {
        assert(dqueue)

        guard let queue = self.queue else { assert(false); return }

        stopping = true
        
        thread?.sync {
            do {
                // end recording
                try checkStatus(AudioQueueStop(queue,
                                               true), "AudioQueueStop failed")
                
                // free buffers
                _ = self.buffers.map({ AudioQueueFreeBuffer(queue, $0) })

                // a codec may update its cookie at the end of an encoding session, so reapply it to the file now
                try checkStatus(AudioQueueDispose(queue,
                                                  true), "AudioQueueDispose failed")
                
                self.queue = nil
                self.thread!.cancel()
                self.thread = nil
            }
            catch {
                logIOError(error)
            }
        }
        
        stopping = false
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Utils
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private let callback: AudioQueueInputCallback = {
        (inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer: AudioQueueBufferRef,
        inStartTime: UnsafePointer<AudioTimeStamp>,
        inNumPackets: UInt32,
        inPacketDesc: UnsafePointer<AudioStreamPacketDescription>?) in
        
        let input = Unmanaged<AudioInput>.fromOpaque(inUserData!).takeUnretainedValue()
        
        guard input.stopping == false else { return }
        
        logIO("audio input \(inStartTime.pointee.seconds())")
        
        do {
            guard let queue = input.queue else { return }
            
            if (inNumPackets > 0) {
                let time = inStartTime.pointee
                let data = NSData(bytes: inBuffer.pointee.mAudioData, length: Int(inBuffer.pointee.mAudioDataByteSize))
                let desc = inPacketDesc != nil ? AudioStreamPacketDescription.ToArray(inPacketDesc!, inNumPackets) : nil
                
                // process input
                
                AV.shared.audioCaptureQueue.async {
                    input.output!.process(AudioData(time, data, desc))
                }

                // simulate gaps
                
//                DispatchQueue.global().async {
//                    let x = arc4random_uniform(1000000)
//                    print("sleep \(Double(x) / 1000000.0)")
//                    usleep(x)
//                    AV.shared.audioCaptureQueue.async {
//                        input.output!.process(AudioData(bytes,
//                                                        bytesSize,
//                                                        packetDesc,
//                                                        inNumPackets,
//                                                        time))
//                    }
//                }
            }
            
            try checkStatus(AudioQueueEnqueueBuffer(input.queue!,
                                                    inBuffer,
                                                    0,
                                                    nil), "AudioQueueEnqueueBuffer failed");
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

}
