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

            cameraSession.startRunning()

        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        callback?(sampleBuffer)
    }

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        print("dropped frame")
    }
}
