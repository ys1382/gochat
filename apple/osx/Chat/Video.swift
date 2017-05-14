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
        let (status, audioBufferList, _) = sampleBuffer.getAudioListAndBlockBuffer()
        if checkError(status) { return }

        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        audio?.formatDescription = asbd?.pointee
        audio?.initializeForAudioQueue()
        audio?.startRunning()

        print("")
        var varAbl = audioBufferList!
        let umAbl = UnsafeMutableAudioBufferListPointer(&varAbl)
        for buffer in umAbl {
            var description = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: buffer.mDataByteSize)
            print("mDataByteSize: \(buffer.mDataByteSize)")
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

    func getAudioListAndBlockBuffer() -> (status: OSStatus, audioBufferList: AudioBufferList?, blockBuffer: CMBlockBuffer?) {

        var bufferListSizeNeededOut: Int = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            &bufferListSizeNeededOut,
            nil,
            0,
            nil,
            nil,
            kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            nil
        )
        if checkError(status) { return (status, nil, nil) }

        let formatDescription = CMSampleBufferGetFormatDescription(self)!
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)!.pointee
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(asbd.mChannelsPerFrame)).unsafeMutablePointer

        var blockBuffer: CMBlockBuffer?
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            nil,
            audioBufferList,
            bufferListSizeNeededOut,
            nil,
            nil,
            kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            &blockBuffer
        )
        if checkError(status) { return (status, nil, nil) }

        return (status, audioBufferList.pointee, blockBuffer)
    }

    func audioCopy(format: CMFormatDescription, timing: CMSampleTimingInfo) -> CMSampleBuffer? {

        let (status1, _, blockBuffer) = self.getAudioListAndBlockBuffer()
        if checkError(status1) { return nil }

        // clone audio CMSampleBuffer
        var sampleBufferOut: CMSampleBuffer?
        var timingInfo = timing
        let numSamples = CMSampleBufferGetNumSamples(self)

        let status2 = CMSampleBufferCreateReady(
            kCFAllocatorDefault,
            blockBuffer,
            format,
            numSamples,
            1,
            &timingInfo,
            0,
            nil,
            &sampleBufferOut)
        if checkError(status2) { return nil }

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
