//
//  Input.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 23/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AudioToolbox
import AVFoundation

class TRAudioInput
{
    private var output: TRAudioOutputProtocol?
    
    private var queue: AudioQueueRef?
    private var	buffer: AudioQueueBufferRef?
    private var format = AudioStreamBasicDescription()
    
    func start(_ formatID: UInt32, _ interval: Double, _ output: TRAudioOutputProtocol) {
        
        // prepare format
        
        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode!.inputFormat(forBus: IOBus.input)
        
        format.mSampleRate = inputFormat.sampleRate;
        format.mChannelsPerFrame = inputFormat.channelCount;
        format.mFormatID = formatID;
        
        if (formatID == kAudioFormatLinearPCM)
        {
            // if we want pcm, default to signed 16-bit little-endian
            format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
            format.mBitsPerChannel = 16;
            format.mBytesPerFrame = (format.mBitsPerChannel / 8) * format.mChannelsPerFrame;
            format.mBytesPerPacket = format.mBytesPerFrame
            format.mFramesPerPacket = 1;
        }

        // start queue
        
        var bufferByteSize: UInt32
        var size: UInt32
        var packetMaxSize: UInt32 = 0

        do {
            // create the queue
            
            try checkStatus(AudioQueueNewInput(
                &format,
                callback,
                Unmanaged.passUnretained(self).toOpaque() /* userData */,
                CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue,
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
        }
        catch {
            logIOError(error.localizedDescription)
        }
        
        // start output
        
        self.output = output
        output.start(&format, packetMaxSize, interval)
    }
    
    func stop() {
        do {
            // end recording
            try checkStatus(AudioQueueStop(queue!,
                                           true), "AudioQueueStop failed")
            
            // a codec may update its cookie at the end of an encoding session, so reapply it to the file now
            try checkStatus(AudioQueueDispose(queue!,
                                              true), "AudioQueueDispose failed")
        }
        catch {
            logIOError(error.localizedDescription)
        }
    }
    
    func computeBufferSize(_ format: AudioStreamBasicDescription,
                           _ interval: Double,
                           _ maxPacketSize: inout UInt32) -> UInt32
    {
        var packets: UInt32
        var frames: UInt32
        var bytes: UInt32 = 0
        
        do {
            frames = UInt32(ceil(interval * format.mSampleRate))
            
            if (format.mBytesPerFrame > 0) {
                bytes = frames * format.mBytesPerFrame
                maxPacketSize = format.mBytesPerPacket
            }
            else {
                if (format.mBytesPerPacket > 0) {
                    maxPacketSize = format.mBytesPerPacket	// constant packet size
                }
                else {
                    var propertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
                    try checkStatus(AudioQueueGetProperty(queue!,
                                                          kAudioQueueProperty_MaximumOutputPacketSize,
                                                          &maxPacketSize,
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
                
                bytes = packets * maxPacketSize;
            }
        }
        catch {
            logIOError(error.localizedDescription)
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
        
        let input = Unmanaged<TRAudioInput>.fromOpaque(inUserData!).takeUnretainedValue()
        
        logIO("audio \(AVAudioTime.seconds(forHostTime: inStartTime.pointee.mHostTime))")
        
        do {
            if (inNumPackets > 0) {
                input.output!.process(inBuffer, inPacketDesc!, inNumPackets, inStartTime)
            }
            
            try checkStatus(AudioQueueEnqueueBuffer(input.queue!,
                                                    input.buffer!,
                                                    0,
                                                    nil), "AudioQueueEnqueueBuffer failed");
        }
        catch {
            logIOError(error.localizedDescription)
        }
        
    }
    
}
