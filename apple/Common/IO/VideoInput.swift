
import AVFoundation
import VideoToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoInput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoInput : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, VideoSessionProtocol {
    
    var sessionAccessor: AVCaptureSession.Accessor {
        get {
            weak var SELFW = self
            
            return { (_ x: (AVCaptureSession) throws -> Void) in
                guard let SELF = SELFW else { return }
                guard let session = SELF.session else { return }
                
                try x(session)
            }
        }
    }
    
    private  var session: AVCaptureSession?
    private let format: AVCaptureDeviceFormat
    private let output: VideoOutputProtocol?
    private let outputQueue: DispatchQueue?
    private let device: AVCaptureDevice?
    private var connection_: AVCaptureConnection?
    
    init(_ device: AVCaptureDevice?,
         _ outputQueue: DispatchQueue?,
         _ format: AVCaptureDeviceFormat,
         _ output: VideoOutputProtocol?) {
        self.output = output
        self.outputQueue = outputQueue
        self.device = device
        self.format = format
        
        super.init()
        initSession()
    }
    
    func initSession() {
        guard let device = self.device else { return }

        session = AVCaptureSession()
        
        // output
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: device)
            
            if (session!.canAddInput(videoDeviceInput) == true) {
                session!.addInput(videoDeviceInput)
            }
            
            try device.lockForConfiguration()
            let fps = CMTime(value: 1, timescale: 10)
            device.activeFormat = format
            device.activeVideoMinFrameDuration = fps
            device.activeVideoMaxFrameDuration = fps
            device.unlockForConfiguration()
            
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
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() throws {
        NotificationCenter.default.addObserver(
            forName: .AVSampleBufferDisplayLayerFailedToDecode,
            object: nil,
            queue: nil,
            using: failureNotification)
        
        assert_video_capture_queue()
        
        try device?.lockForConfiguration()

        try dispatch_sync_on_main {
            try sessionAccessor({ (_ session: AVCaptureSession) throws in
                session.startRunning()
            })
        }
    }
    
    func stop() {
        assert_video_capture_queue()

        session?.stopRunning()
        session = nil
        device?.unlockForConfiguration()
    }
    
    func update(_ outputFormat: VideoFormat) throws {
        // don't change input dimensions because we also showing preview
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // AVCaptureVideoDataOutputSampleBufferDelegate and failure notification
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func formatNotChanged(_ sampleBuffer: CMSampleBuffer) -> Bool {
        let sampleDimentions = CMVideoFormatDescriptionGetDimensions(CMSampleBufferGetFormatDescription(sampleBuffer)!)
        
        return format.dimensions == sampleDimentions || format.dimensions == sampleDimentions.turn()
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
       
        assert(formatNotChanged(sampleBuffer))
        
        self.output?.process(sampleBuffer)
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
    let session: AVCaptureSession.Accessor
    
    convenience init(_ layer: AVCaptureVideoPreviewLayer,
                     _ session: @escaping AVCaptureSession.Accessor) {
        self.init(layer, session, nil)
    }

    init(_ layer: AVCaptureVideoPreviewLayer,
         _ session: @escaping AVCaptureSession.Accessor,
         _ next: VideoSessionProtocol?) {
        self.layer = layer
        self.session = session
        super.init(next)
    }

    override func start() throws {
        
        try dispatch_sync_on_main {
            try session({ (session: AVCaptureSession) in
                layer.session = session
                layer.connection.automaticallyAdjustsVideoMirroring = false
                layer.connection.isVideoMirrored = false
            })
        }

        try super.start()
    }
    
    override func stop() {
        super.stop()
        
        dispatch_sync_on_main {
            layer.session = nil
        }
    }
}
