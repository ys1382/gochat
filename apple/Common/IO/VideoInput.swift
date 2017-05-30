
import AVFoundation
import VideoToolbox

class VideoInput : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public  var session = AVCaptureSession()
    private var output: VideoOutputProtocol?
    private var device: AVCaptureDevice?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Interface
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    init(_ device: AVCaptureDevice?, _ output: VideoOutputProtocol?) {
        self.output = output
        self.device = device
    }
    
    func start() {
        NotificationCenter.default.addObserver(
            forName: .AVSampleBufferDisplayLayerFailedToDecode,
            object: nil,
            queue: nil,
            using: failureNotification)
        
        // capture session
        
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetLow
        session.commitConfiguration()
        session.startRunning()
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: device)
            
            if (session.canAddInput(videoDeviceInput) == true) {
                session.addInput(videoDeviceInput)
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            let videoQueue = DispatchQueue(label: "videoQueue")
            
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (session.canAddOutput(videoDataOutput) == true) {
                session.addOutput(videoDataOutput)
            }
        } catch {
            logIOError(error)
        }
    }
    
    func stop() {
        session.stopRunning()
        output = nil
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // AVCaptureVideoDataOutputSampleBufferDelegate and failure notification
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
       
        logIO("video \(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))")
        output?.process(sampleBuffer)
    }
    
    func failureNotification(notification: Notification) {
        logIOError("failureNotification " + notification.description)
    }

}
