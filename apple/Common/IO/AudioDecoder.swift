
import AudioToolbox

class AudioDecoder : AudioOutputProtocol, IOSessionProtocol {
    
    var input: AudioFormat.Factory
    var output: AudioStreamBasicDescription.Factory
    let next: AudioOutput?
    
    var converter: AudioConverterRef?
    var inputDescription: AudioStreamBasicDescription?
    var outputDescription: AudioStreamBasicDescription?
    var asc: UInt8 = 0

    var pcmDataSize: UInt32 = 0
    var pcmBufferList: AudioBufferList?
    
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
            
            if pcmBufferList != nil {
                free(pcmBufferList!.mBuffers.mData)
                pcmBufferList = nil
            }
        }
        catch {
            logIOError(error)
        }
    }
    
    func process(_ packet: AudioData) {
        
        guard let converter = self.converter else { return }
                
        // asc
        
        if (asc == 0 && packet.data.length == 2) {
            logIO("asc size \(packet.data.length)")
            memcpy(&asc, packet.data.bytes, 2);
            return;
        }
        // adts
        
        else if (packet.data.length == 7 || packet.data.length == 9) {
            logIO("adts size \(packet.data.length)")
            return;
        }
        
        var pcmPacketNum = inputDescription!.mFramesPerPacket * UInt32(packet.desc!.count)
        let pcmDataSize = pcmPacketNum * outputDescription!.mBytesPerPacket
        
        _prepareBufferList(pcmDataSize)
        
        do {
            var copy = packet
            try checkStatus(AudioConverterFillComplexBuffer(converter,
                                                            decodeProc,
                                                            &copy,
                                                            &pcmPacketNum,
                                                            &pcmBufferList!,
                                                            nil),
                            "AudioConverterFillComplexBuffer")

            next?.process(AudioData(packet.time,
                                    NSData(bytes: pcmBufferList!.mBuffers.mData, length: Int(pcmDataSize)),
                                    nil))
        }
        catch {
            logIOError(error)
        }
    }

    private let decodeProc: AudioConverterComplexInputDataProc = {(
        converter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
        userData: UnsafeMutableRawPointer?) -> OSStatus in
        
        let packet = UnsafePointer<AudioData>(OpaquePointer(userData!))
        
        // data
        
        var bufferList = AudioBufferList()
        
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mData = UnsafeMutableRawPointer(OpaquePointer(packet.pointee.data.bytes))
        bufferList.mBuffers.mDataByteSize = UInt32(packet.pointee.data.length)
        bufferList.mBuffers.mNumberChannels = 1
        ioData.initialize(to: bufferList)
        
        // descriptions
        
        var desc = packet.pointee.desc
        
        desc?.withUnsafeMutableBufferPointer({
            (ptr: inout UnsafeMutableBufferPointer<AudioStreamPacketDescription>) -> Void in
            outDataPacketDescription?.initialize(to: ptr.baseAddress!)
        })

        ioNumberDataPackets.pointee = UInt32(packet.pointee.desc!.count)

        return 0
    }
    
    private func _prepareBufferList(_ size: UInt32) {
        if size <= pcmDataSize {
            pcmBufferList!.mBuffers.mDataByteSize = size
            return
        }
        
        if pcmBufferList != nil {
            free(pcmBufferList!.mBuffers.mData)
        }
        
        let pcmBuffer = AudioBuffer(mNumberChannels: 1,
                                mDataByteSize: size,
                                mData: malloc(Int(size)))
        pcmBufferList = AudioBufferList(mNumberBuffers: 1,
                                        mBuffers: pcmBuffer)
        pcmDataSize = size
    }
}
