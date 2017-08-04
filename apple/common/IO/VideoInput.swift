
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
    private var format: AVCaptureDeviceFormat
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
        assert_video_capture_queue()
        logIOPrior("video input start")

        NotificationCenter.default.addObserver(
            forName: .AVSampleBufferDisplayLayerFailedToDecode,
            object: nil,
            queue: nil,
            using: failureNotification)
        
        try device?.lockForConfiguration()

        try dispatch_sync_on_main {
            try sessionAccessor({ (_ session: AVCaptureSession) throws in
                session.startRunning()
            })
        }
    }
    
    func stop() {
        assert_video_capture_queue()
        logIOPrior("video input stop")

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
        logIO("video input \(sampleBuffer.seconds())")

//        #if os(iOS)
        self.output?.process(sampleBuffer)
//        #else
//        AV.shared.videoCaptureQueue.asyncAfter0_5 { self.output?.process(sampleBuffer) }
//        #endif
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
        logIOPrior("video preview start")

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
        logIOPrior("video preview stop")

        super.stop()
        
        dispatch_sync_on_main {
            layer.session = nil
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VideoInputQoS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VideoInputQoS : IOQoSProtocol {
    
    let input: VideoSessionProtocol
    let format: AVCaptureDeviceFormat
    var dimensions: CMVideoDimensions
    
    init(_ format: AVCaptureDeviceFormat, _ input: VideoSessionProtocol) {
        self.input = input
        self.format = format
        self.dimensions = format.dimensions
    }
    
    func change(_ toQID: String, _ diff: Int) {
        guard diff != IOQoS.kInit else { return }

        do {
            let dimensions = CMVideoDimensions(width: self.dimensions.width / 2,
                                               height: self.dimensions.height / 2)
            
            if dimensions.width > 100 {
                try input.update(VideoFormat(dimensions))
                self.dimensions = dimensions
                
                logIOPrior("video quality changed to \(dimensions.width) * \(dimensions.height)")
            }
            else {
                
            }
        }
        catch {
            logIOError(error)
        }
    }
}
