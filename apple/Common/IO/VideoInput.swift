
import AVFoundation
import VideoToolbox

class VideoInput : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, IOSessionProtocol {
    
    public  var session: AVCaptureSession?
    private let output: VideoOutputProtocol?
    private let outputQueue: DispatchQueue?
    private let device: AVCaptureDevice?
    private let preview: AVCaptureVideoPreviewLayer?
    
    init(_ device: AVCaptureDevice?,
         _ preview: AVCaptureVideoPreviewLayer?,
         _ outputQueue: DispatchQueue?,
         _ output: VideoOutputProtocol?) {
        self.output = output
        self.outputQueue = outputQueue
        self.device = device
        self.preview = preview
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() throws {
        NotificationCenter.default.addObserver(
            forName: .AVSampleBufferDisplayLayerFailedToDecode,
            object: nil,
            queue: nil,
            using: failureNotification)
        
        // capture session
        
        session = AVCaptureSession()
        
        session!.beginConfiguration()
        session!.sessionPreset = AVCaptureSessionPresetLow
        session!.commitConfiguration()
        session!.startRunning()
        
        // output
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: device)
            
            if (session!.canAddInput(videoDeviceInput) == true) {
                session!.addInput(videoDeviceInput)
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            
            videoDataOutput.setSampleBufferDelegate(self, queue: outputQueue)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (session!.canAddOutput(videoDataOutput) == true) {
                session!.addOutput(videoDataOutput)
            }
        } catch {
            logIOError(error)
            stop()
        }
        
        // preview
        
        DispatchQueue.main.async {
            self.preview?.session = self.session
        }
    }
    
    func stop() {
        session?.stopRunning()
        session = nil
        preview?.session = nil
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
