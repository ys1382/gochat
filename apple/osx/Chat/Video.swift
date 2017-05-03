import Cocoa
import AVFoundation

class Video: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    var cameraSession = AVCaptureSession()
    var callback: ((CMSampleBuffer)->())?

    override init() {

    }

    func start(callback:@escaping (CMSampleBuffer)->()) {
        self.callback = callback

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
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32ARGB)]
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

            cameraSession.startRunning()

        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {

        if let sb2 = self.serialize(sampleBuffer) {
            callback?(sb2)
        }
    }

    func pixelBufferCopy(_ pixelBufferIn : CVPixelBuffer) -> CVPixelBuffer? {
        if CVPixelBufferIsPlanar(pixelBufferIn) {
            print("planar")
            return nil
        }
        let lockFlags = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(pixelBufferIn, lockFlags)


        let attachments = CMGetAttachment(pixelBufferIn, "CVImageBufferColorPrimaries" as CFString, nil)


        let baseAddress = CVPixelBufferGetBaseAddress(pixelBufferIn)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBufferIn)
        let width = CVPixelBufferGetWidth(pixelBufferIn)
        let height = CVPixelBufferGetHeight(pixelBufferIn)
        let format = CVPixelBufferGetPixelFormatType(pixelBufferIn)

        var pixelBufferOut: CVPixelBuffer?

        let result = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            format,
            baseAddress!,
            bytesPerRow,
            nil,
            nil,
            nil,
            &pixelBufferOut);

        if (result != kCVReturnSuccess) {
            print("CVPixelBufferCreateWithPlanarBytes failed: \(result)")
            return nil
        }

        CVPixelBufferUnlockBaseAddress(pixelBufferIn, lockFlags)
        return pixelBufferOut
    }

    func serialize(_ sampleBufferIn: CMSampleBuffer) -> CMSampleBuffer? {
        guard let pixelBufferIn : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBufferIn) else {
//            let pixelBufferOut = pixelBufferCopy(pixelBufferIn) else {
            print("could not get image buffer")
            return nil
        }
        let pixelBufferOut = pixelBufferIn.copy()

        var count: CMItemCount = 1
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(sampleBufferIn, count, &timingInfo, &count)

        let formatDescription = CMSampleBufferGetFormatDescription(sampleBufferIn)!

        var sampleBufferOut: CMSampleBuffer?

        let status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            pixelBufferOut,
            formatDescription,
            &timingInfo,
            &sampleBufferOut)

        if checkError(status) {
            return nil
        }

        return sampleBufferOut
    }

    func checkError(_ status: OSStatus) -> Bool {
        if status != noErr {
            print("Error " + status.description)
            return true
        }
        return false
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        print("dropped frame")
    }
}

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

        var _copy : CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &_copy)

        guard let copy = _copy else { fatalError() }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))

        memcpy(
            CVPixelBufferGetBaseAddress(copy),
            CVPixelBufferGetBaseAddress(self),
            CVPixelBufferGetDataSize(self))

        CVPixelBufferUnlockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        let attachments = CVBufferGetAttachments(self, .shouldPropagate)
        CVBufferSetAttachments(copy, attachments!, .shouldPropagate)

        return copy
    }
}
