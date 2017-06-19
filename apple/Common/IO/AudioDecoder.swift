//
//  AudioDecoderAAC.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 15/06/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AudioToolbox

class AudioDecoder : AudioOutputProtocol, IOSessionProtocol {
    
    var input: AudioFormat.Factory
    var output: AudioStreamBasicDescription.Factory
    let next: AudioOutput?
    
    var converter: AudioConverterRef?
    var inputDescription: AudioStreamBasicDescription?
    var outputDescription: AudioStreamBasicDescription?
    var asc: UInt8 = 0

    init(_ input: @escaping AudioFormat.Factory,
         _ output: @escaping AudioStreamBasicDescription.Factory,
         _ next: AudioOutput?) {
        self.input = input
        self.output = output
        self.next = next
    }
    
    func start() throws {
        guard var outputDescription = try self.output() else { return }
        outputDescription.mChannelsPerFrame = 1
        
        self.inputDescription = AudioStreamBasicDescription.CreateVBR(self.input())
        self.outputDescription = outputDescription
        
        try checkStatus(AudioConverterNew(&inputDescription!, &outputDescription, &converter),
                        "decoder: AudioConverterNew")
    }
    
    func stop() {
        guard let converter = self.converter else { return }

        do {
            try checkStatus(AudioConverterDispose(converter),
                            "AudioConverterDispose")
            self.converter = nil
        }
        catch {
            logIOError(error)
        }
    }
    
    func process(_ data: AudioData) {
        
        guard let converter = self.converter else { return }
                
        // asc
        
        if (asc == 0 && data.bytesNum == 2) {
            logIO("asc size \(data.bytesNum)")
            memcpy(&asc, data.bytes, 2);
            return;
        }
        // adts
        
        else if (data.bytesNum == 7 || data.bytesNum == 9) {
            logIO("adts size \(data.bytesNum)")
            return;
        }
        
        var pcmPacketNum = inputDescription!.mFramesPerPacket * data.packetNum
        let pcmDataSize = pcmPacketNum * outputDescription!.mBytesPerPacket
        
        var pcmBufferList = AudioBufferList(mNumberBuffers: 1,
                                         mBuffers: AudioBuffer(mNumberChannels: 1,
                                                               mDataByteSize: pcmDataSize,
                                                               mData: malloc(Int(pcmDataSize))))
        
        do {
            var dataCopy = data
            
            try checkStatus(AudioConverterFillComplexBuffer(converter,
                                                            decodeProc,
                                                            &dataCopy,
                                                            &pcmPacketNum,
                                                            &pcmBufferList,
                                                            nil),
                            "AudioConverterFillComplexBuffer")
        }
        catch {
            logIOError(error)
        }
        
        next?.process(AudioData(UnsafeMutablePointer(OpaquePointer((pcmBufferList.mBuffers.mData!))),
                                pcmDataSize,
                                nil,
                                pcmPacketNum,
                                data.timeStamp))
    }

    private let decodeProc: AudioConverterComplexInputDataProc = {(
        converter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
        userData: UnsafeMutableRawPointer?) -> OSStatus in
        
        let data = UnsafePointer<AudioData>(OpaquePointer(userData!))
        
        ioNumberDataPackets.pointee = data.pointee.packetNum
        
        var bufferList = AudioBufferList()
        
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mData = UnsafeMutableRawPointer(OpaquePointer(data.pointee.bytes))
        bufferList.mBuffers.mDataByteSize = data.pointee.bytesNum
        bufferList.mBuffers.mNumberChannels = 1
        
        var packetDescriptions = UnsafeMutablePointer<AudioStreamPacketDescription>(mutating: data.pointee.packetDesc)
        
        ioData.initialize(to: bufferList)
        outDataPacketDescription?.initialize(to: packetDescriptions)
        
        return 0
    }
}
