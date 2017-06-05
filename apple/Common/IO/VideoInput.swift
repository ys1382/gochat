
import AVFoundation
import VideoToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoInput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoInput : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, VideoSessionProtocol {
    
    public  var session: AVCaptureSession?
   
    private let output: VideoOutputProtocol?
    private let outputQueue: DispatchQueue?
    private let device: AVCaptureDevice?
    private var connection_: AVCaptureConnection?
    
    init(_ device: AVCaptureDevice?,
         _ outputQueue: DispatchQueue?,
         _ output: VideoOutputProtocol?) {
        self.output = output
        self.outputQueue = outputQueue
        self.device = device
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
                connection_ = videoDataOutput.connection(withMediaType: AVMediaTypeVideo)
            }
        } catch {
            logIOError(error)
            stop()
        }
    }
    
    func stop() {
        session?.stopRunning()
        session = nil
    }
    
    func update(_ outputFormat: VideoFormat) throws {
        // don't change input dimentions because we also showing preview
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoPreview
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoPreview : VideoSession {
    
    let layer: AVCaptureVideoPreviewLayer
    let session: AVCaptureSession.Factory
    let next: VideoSessionProtocol?
    
    convenience init(_ layer: AVCaptureVideoPreviewLayer,
         _ session: @escaping AVCaptureSession.Factory) {
        self.init(layer, session, nil)
    }

    init(_ layer: AVCaptureVideoPreviewLayer,
         _ session: @escaping AVCaptureSession.Factory,
         _ next: VideoSessionProtocol?) {
        self.layer = layer
        self.session = session
        self.next = next
    }

    override func start() throws {
        try next?.start()
        
        dispatch_sync_on_main {
            layer.session = session()
            layer.connection.automaticallyAdjustsVideoMirroring = false
            layer.connection.isVideoMirrored = false
        }
    }
    
    override func stop() {
        next?.stop()
        
        dispatch_sync_on_main {
            layer.session = nil
        }
    }
    
}
