import Foundation

import AudioToolbox
import AVFoundation
import AudioToolbox
import AVFoundation

let kInputBus: UInt32 = 1
let kOutputBus: UInt32 = 0
let sizeofFlag: UInt32 = UInt32(MemoryLayout<UInt32>.size)

class Audio:
    NSObject,
    IOProtocol,
    AVCaptureAudioDataOutputSampleBufferDelegate
{

    static let defaultBufferSize:UInt32 = 128 * 1024
    static let defaultNumberOfBuffers:Int = 128
    static let defaultMaxPacketDescriptions:Int = 1

    var captureSession: AVCaptureSession!
    
    var await:Bool = false
    var runloop:CFRunLoop? = nil
    var numberOfBuffers:Int = Audio.defaultNumberOfBuffers
    var maxPacketDescriptions:Int = Audio.defaultMaxPacketDescriptions
    fileprivate(set) var running:Bool = false
    var formatDescription:AudioStreamBasicDescription? = nil

    let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioStreamPlayback.lock")
    fileprivate var bufferSize:UInt32 = Audio.defaultBufferSize
    fileprivate var queue:AudioQueueRef? = nil {
        didSet {
            guard let oldValue:AudioQueueRef = oldValue else {
                return
            }
            AudioQueueStop(oldValue, true)
            AudioQueueDispose(oldValue, true)
        }
    }
    fileprivate var inuse:[Bool] = []
    fileprivate var buffers:[AudioQueueBufferRef] = []
    fileprivate var current:Int = 0
    fileprivate var started:Bool = false
    fileprivate var filledBytes:UInt32 = 0
    fileprivate var packetDescriptions:[AudioStreamPacketDescription] = []
    fileprivate var fileStreamID:AudioFileStreamID? = nil {
        didSet {
            guard let oldValue:AudioFileStreamID = oldValue else {
                return
            }
            AudioFileStreamClose(oldValue)
        }
    }
    fileprivate var isPacketDescriptionsFull:Bool {
        return packetDescriptions.count == maxPacketDescriptions
    }

    fileprivate var outputCallback:AudioQueueOutputCallback = {(
        inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer:AudioQueueBufferRef) -> Void in
        print("outputCallback")
        let playback:Audio = unsafeBitCast(inUserData, to: Audio.self)
        playback.onOutputForQueue(inAQ, inBuffer)
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func start()
    {
        
    }
    
    func stop()
    {
        
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Setup
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func setup(session: AVCaptureSession)
    {
        self.captureSession = session
        
        let audioCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) as AVCaptureDevice
        
        do
        {
            // inputs
           
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioCaptureDevice)
            
            if captureSession.canAddInput(audioDeviceInput)
            {
                captureSession.addInput(audioDeviceInput)
            }
            else
            {
                print("Could not add audio device input to the session")
            }
            
            // outputs
            
            let audioDataOutput = AVCaptureAudioDataOutput()
            let audioQueue = DispatchQueue(label: "audioQueue")
            
            audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)

            if (captureSession.canAddOutput(audioDataOutput) == true)
            {
                captureSession.addOutput(audioDataOutput)
            }
            
        }
        catch let error as NSError
        {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!)
    {
        let sampleBufferCopy = sampleBuffer.copy()!
        let (status, audioBufferList, _) = sampleBufferCopy.getAudioListAndBlockBuffer()
       
        if checkError(status) { return }
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBufferCopy)!
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
       
        self.formatDescription = asbd?.pointee
        self.initializeForAudioQueue()
        self.startRunning()
        
        print("")
        
        for buffer in audioBufferList!
        {
            var description = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: buffer.mDataByteSize)
            print("mDataByteSize: \(buffer.mDataByteSize)")
            appendBuffer(buffer.mData!, inPacketDescription: &description)
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!)
    {
        print("dropped audio frame")
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func initializeForAudioQueue() {
        guard let _:AudioStreamBasicDescription = formatDescription, self.queue == nil else {
            return
        }
        var queue:AudioQueueRef? = nil
        DispatchQueue.global(qos: .background).sync {
            self.runloop = CFRunLoopGetCurrent()
            AudioQueueNewOutput(
                &self.formatDescription!,
                self.outputCallback,
                unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                self.runloop,
                CFRunLoopMode.commonModes.rawValue,
                0,
                &queue)
        }

        for _ in 0..<numberOfBuffers {
            var buffer:AudioQueueBufferRef? = nil
            AudioQueueAllocateBuffer(queue!, bufferSize, &buffer)
            if let buffer:AudioQueueBufferRef = buffer {
                buffers.append(buffer)
            }
        }
        self.queue = queue
    }

    final func onOutputForQueue(_ inAQ: AudioQueueRef, _ inBuffer:AudioQueueBufferRef) {
        guard let i:Int = buffers.index(of: inBuffer) else {
            return
        }
        objc_sync_enter(inuse)
        inuse[i] = false
        objc_sync_exit(inuse)
    }

    func isBufferFull(_ packetSize:UInt32) -> Bool {
        return (bufferSize - filledBytes) < packetSize
    }

    func appendBuffer(_ inInputData:UnsafeRawPointer, inPacketDescription:inout AudioStreamPacketDescription) {
        let offset:Int = Int(inPacketDescription.mStartOffset)
        let packetSize:UInt32 = inPacketDescription.mDataByteSize
        if (isBufferFull(packetSize) || isPacketDescriptionsFull) {
            enqueueBuffer()
            rotateBuffer()
        }
        let buffer:AudioQueueBufferRef = buffers[current]
        memcpy(buffer.pointee.mAudioData.advanced(by: Int(filledBytes)), inInputData.advanced(by: offset), Int(packetSize))
        inPacketDescription.mStartOffset = Int64(filledBytes)
        packetDescriptions.append(inPacketDescription)
        filledBytes += packetSize
    }

    func rotateBuffer() {
        current += 1
        if (numberOfBuffers <= current) {
            current = 0
        }
        filledBytes = 0
        packetDescriptions.removeAll()
        var loop:Bool = true
        repeat {
            objc_sync_enter(inuse)
            loop = inuse[current]
            objc_sync_exit(inuse)
        }
            while(loop)
    }

    func enqueueBuffer() {
        guard let queue:AudioQueueRef = queue, running else {
            return
        }
        inuse[current] = true
        let buffer:AudioQueueBufferRef = buffers[current]
        buffer.pointee.mAudioDataByteSize = filledBytes
        guard AudioQueueEnqueueBuffer(
            queue,
            buffer,
            UInt32(packetDescriptions.count),
            &packetDescriptions) == noErr else {
                print("AudioQueueEnqueueBuffer error")
                return
        }
        startQueueIfNeed()
    }

    func startQueueIfNeed() {
        guard let queue:AudioQueueRef = queue, !started else {
            return
        }
        started = true
        AudioQueuePrime(queue, 0, nil)
        AudioQueueStart(queue, nil)
    }
}

extension Audio: Runnable {
    // MARK: Runnable
    func startRunning() {
        lockQueue.async {
            guard !self.running else {
                return
            }
            self.inuse = [Bool](repeating: false, count: self.numberOfBuffers)
            self.started = false
            self.current = 0
            self.filledBytes = 0
            self.packetDescriptions.removeAll()
            self.running = true
            AudioUtil.startRunning()
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.running else {
                return
            }
            self.queue = nil
            if let runloop:CFRunLoop = self.runloop {
                CFRunLoopStop(runloop)
            }
            self.runloop = nil
            self.inuse.removeAll()
            self.buffers.removeAll()
            self.started = false
            self.fileStreamID = nil
            self.packetDescriptions.removeAll()
            self.running = false
            AudioUtil.stopRunning()
        }
    }
}

final class AudioUtil {

    fileprivate static var defaultDeviceID:AudioObjectID {
        var deviceID:AudioObjectID = AudioObjectID(0)
        var size:UInt32 = UInt32(MemoryLayout<AudioObjectID>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        address.mScope = kAudioObjectPropertyScopeGlobal;
        address.mElement = kAudioObjectPropertyElementMaster;
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    fileprivate init() {
    }

    static func setInputGain(_ volume:Float32) -> OSStatus {
        var inputVolume:Float32 = volume
        let size:UInt32 = UInt32(MemoryLayout<Float32>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = kAudioObjectPropertyElementMaster
        return AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &inputVolume)
    }

    static func getInputGain() -> Float32{
        var volume:Float32 = 0.5
        var size:UInt32 = UInt32(MemoryLayout<Float32>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = kAudioObjectPropertyElementMaster
        AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &volume)
        return volume
    }

    static func startRunning() {
    }

    static func stopRunning() {
    }
}

protocol Runnable: class {
    var running:Bool { get }
    func startRunning()
    func stopRunning()
}

protocol Iterator {
    associatedtype T
    func hasNext() -> Bool
    func next() -> T?
}

