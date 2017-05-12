// todo: add h264 encoding/decoding from https://github.com/shogo4405/lf.swift/tree/master/Sources/Media

import Cocoa
import AVFoundation

class Video: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    var cameraSession = AVCaptureSession()
    var videoCallback: ((CMSampleBuffer)->())?
    var audio: Audio?

    override init() {}

    func start(videoCallback:@escaping (CMSampleBuffer)->()) {
        audio = Audio()
        self.videoCallback = videoCallback

        NotificationCenter.default.addObserver(forName: .AVSampleBufferDisplayLayerFailedToDecode,
                                               object: nil,
                                               queue: nil,
                                               using: failureNotification)
        self.setupCameraSession()
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
         return AVCaptureVideoPreviewLayer(session: self.cameraSession)
    }

    func failureNotification(notification: Notification) {
        print("failureNotification" + notification.description)
    }

    lazy var networkLayer: AVSampleBufferDisplayLayer = {
        var layer = AVSampleBufferDisplayLayer()
        return layer
    }()

    func setupCameraSession() {

        self.cameraSession = AVCaptureSession()
        cameraSession.sessionPreset = AVCaptureSessionPresetLow

        let videoCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
        let audioCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio) as AVCaptureDevice

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            cameraSession.beginConfiguration()

            // inputs
            if (cameraSession.canAddInput(videoDeviceInput) == true) {
                cameraSession.addInput(videoDeviceInput)
            }
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioCaptureDevice)

            if cameraSession.canAddInput(audioDeviceInput) {
                cameraSession.addInput(audioDeviceInput)
            }
            else {
                print("Could not add audio device input to the session")
            }

            // outputs
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            if (cameraSession.canAddOutput(videoDataOutput) == true) {
                cameraSession.addOutput(videoDataOutput)
            }
            let audioDataOutput = AVCaptureAudioDataOutput()
            if (cameraSession.canAddOutput(audioDataOutput) == true) {
                cameraSession.addOutput(audioDataOutput)
            }

            cameraSession.commitConfiguration()

            let videoQueue = DispatchQueue(label: "videoQueue")
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)

            let audioQueue = DispatchQueue(label: "audioQueue")
            audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)

            cameraSession.startRunning()

        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {

        if let sampleBufferOut = sampleBuffer.copy(), let mediaType = sampleBufferOut.getMediaType() {
            switch mediaType {
            case kCMMediaType_Audio:
                audioCallback(sampleBufferOut)
            case kCMMediaType_Video:
                videoCallback?(sampleBufferOut)
            default:
                print("did not handle format description type \(mediaType)")
            }
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        print("dropped frame")
    }

    func audioCallback(_ sampleBuffer: CMSampleBuffer) {
        print("audioCallback")
        var blockBuffer: CMBlockBuffer?
        var audioBufferList: AudioBufferList = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            nil,
            &audioBufferList,
            MemoryLayout<AudioBufferList>.size,
            nil,
            nil,
            0,
            &blockBuffer
        )
        if checkError(status) { return }

        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        audio?.formatDescription = asbd?.pointee
        audio?.initializeForAudioQueue()
        audio?.startRunning()

        let ffs = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        ffs.initialize(to: audioBufferList)
        let abl = UnsafeMutableAudioBufferListPointer(ffs)
        for buffer in abl {
            var description = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: buffer.mDataByteSize)
            audio?.appendBuffer(buffer.mData!, inPacketDescription: &description)
        }
    }
}

func checkError(_ status: OSStatus) -> Bool {
    if status != noErr {
        print("Error " + status.description)
        return true
    }
    return false
}

extension CMSampleBuffer {
    func copy() -> CMSampleBuffer? {

        let formatDescription = CMSampleBufferGetFormatDescription(self)!
        guard let formatDescriptionOut = formatDescription.copy() else {
            return nil
        }

        var count: CMItemCount = 1
        var timingInfoIn = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(self, count, &timingInfoIn, &count)
        let timingInfoOut = timingInfoIn.copy()

        switch CMFormatDescriptionGetMediaType(formatDescription) {
        case kCMMediaType_Audio:
            return audioCopy(format: formatDescriptionOut, timing: timingInfoOut)
        case kCMMediaType_Video:
            return videoCopy(format: formatDescriptionOut, timing: timingInfoOut)
        default:
            print("did not handle format description type \(CMFormatDescriptionGetMediaType(formatDescription))")
            return nil
        }
    }

    func getMediaType() -> CMMediaType? {
        if let formatDescription = CMSampleBufferGetFormatDescription(self) {
            return CMFormatDescriptionGetMediaType(formatDescription)
        }
        return nil
    }

    func audioCopy(format: CMFormatDescription, timing: CMSampleTimingInfo) -> CMSampleBuffer? {

        var blockBuffer: CMBlockBuffer?
        var audioBufferList: AudioBufferList = AudioBufferList()
        let numSamples = CMSampleBufferGetNumSamples(self)

        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            nil,
            &audioBufferList,
            MemoryLayout<AudioBufferList>.size,
            nil,
            nil,
            0,
            &blockBuffer
        )
        if checkError(status) { return nil }


        // clone audio CMSampleBuffer
        var sampleBufferOut: CMSampleBuffer?
        var timingInfo = timing
        status = CMSampleBufferCreateReady(
            kCFAllocatorDefault,
            blockBuffer,
            format,
            numSamples,
            1,
            &timingInfo,
            0,
            nil,
            &sampleBufferOut)
        if checkError(status) { return nil }

        return sampleBufferOut
    }

    func videoCopy(format: CMFormatDescription, timing: CMSampleTimingInfo) -> CMSampleBuffer? {
        guard let pixelBufferIn : CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("could not get image buffer")
            return nil
        }
        let pixelBufferOut = pixelBufferIn.copy()

        var timingInfo = timing
        var sampleBufferOut: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            pixelBufferOut,
            format,
            &timingInfo,
            &sampleBufferOut)

        if checkError(status) { return nil }
        return sampleBufferOut
    }
}

extension CMFormatDescription {
    func copy() -> CMFormatDescription? {
        let extensions = CMFormatDescriptionGetExtensions(self)
        let mediaType = CMFormatDescriptionGetMediaType(self)

        var formatOut: CMFormatDescription?
        var status: OSStatus
        switch mediaType {
        case kCMMediaType_Audio:
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(self)
            status = CMAudioFormatDescriptionCreate(
                nil,
                asbd!,
                0,
                nil,
                0,
                nil,
                extensions,
                &formatOut)
        case kCMMediaType_Video:
            let codecType = CMFormatDescriptionGetMediaSubType(self)
            let dimensions = CMVideoFormatDescriptionGetDimensions(self)
            status = CMVideoFormatDescriptionCreate(
                nil,
                codecType,
                dimensions.width,
                dimensions.height,
                extensions,
                &formatOut)
        default:
            status = noErr
            print("did not handle format description media type \(mediaType)")
        }
        if checkError(status) { return nil }
        return formatOut
    }
}

extension CMSampleTimingInfo {
    func copy() -> CMSampleTimingInfo {
        let durationIn = self.duration
        let presentationIn = self.presentationTimeStamp
        let decodeIn = kCMTimeInvalid
        return CMSampleTimingInfo(duration: durationIn, presentationTimeStamp: presentationIn, decodeTimeStamp: decodeIn)
    }
}

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

        var pixelBufferCopy : CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &pixelBufferCopy)

        guard let pixelBufferOut = pixelBufferCopy else { fatalError() }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(pixelBufferOut, CVPixelBufferLockFlags(rawValue: 0))

        memcpy(
            CVPixelBufferGetBaseAddress(pixelBufferOut),
            CVPixelBufferGetBaseAddress(self),
            CVPixelBufferGetDataSize(self))

        CVPixelBufferUnlockBaseAddress(pixelBufferOut, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        let attachments = CVBufferGetAttachments(self, .shouldPropagate)
        var dict = attachments as! [String: AnyObject]
        dict["MetadataDictionary"] = nil // because not needed (probably)
        CVBufferSetAttachments(pixelBufferOut, dict as CFDictionary, .shouldPropagate)

        return pixelBufferOut
    }
}
