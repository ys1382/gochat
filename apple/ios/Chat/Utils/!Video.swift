
import AVFoundation
import UIKit

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ChatVideoInputSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ChatVideoInputSession : VideoSession {
    
    fileprivate let connection: AVCaptureConnection.Factory
    
    init(_ connection: @escaping AVCaptureConnection.Factory,
         _ next: VideoSessionProtocol?) {
        self.connection = connection
        super.init(next)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func start() throws {
        connection()?.automaticallyAdjustsVideoMirroring = false
        connection()?.isVideoMirrored = false
        
        updateOrientation(UIDevice.current.orientation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didRotate),
                                               name: NSNotification.Name.UIDeviceOrientationDidChange,
                                               object: nil)

        try super.start()
    }
    
    override func stop() {
        super.stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func update(_ outputFormat: VideoFormat) throws {
        try super.update(outputFormat)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Orientation
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    fileprivate func updateOrientation(_ to: UIDeviceOrientation) {
        guard let orientation = AVCaptureVideoOrientation.Create(to) else { return }
        
        connection()?.videoOrientation = orientation
    }

    @objc fileprivate func didRotate() {
        updateOrientation(UIDevice.current.orientation)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ChatVideoCaptureSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ChatVideoCaptureSession : ChatVideoInputSession {
    
    private var outputFormat: VideoFormat
    private var updatedFormat: VideoFormat
    private var orientation: AVCaptureVideoOrientation

    init(_ connection: @escaping AVCaptureConnection.Factory,
         _ outputFormat: VideoFormat,
         _ orientation: AVCaptureVideoOrientation,
         _ next: VideoSessionProtocol?) {
        self.outputFormat = outputFormat
        self.updatedFormat = outputFormat
        self.orientation = orientation
        
        super.init(connection, next)
    }

    override func update(_ outputFormat: VideoFormat) throws {
        updatedFormat = outputFormat

        AV.shared.avCaptureQueue.async {
            do {
                try super.update(outputFormat)
            }
            catch {
                logIOError(error)
            }
        }
    }
    
    func updateFormat(_ to: UIDeviceOrientation) {
        guard let orientation = AVCaptureVideoOrientation.Create(to) else { return }

        if self.orientation.rotates(orientation) {
            var outputFormat = self.outputFormat
            
            outputFormat.width = self.outputFormat.height
            outputFormat.height = self.outputFormat.width

            if outputFormat != updatedFormat {
                try! update(outputFormat)
                self.outputFormat = outputFormat
            }
        }
        
        self.orientation = orientation
    }
    
    override func didRotate() {
        let orientation = UIDevice.current.orientation
        
        super.didRotate()
        
        self.updateFormat(orientation)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ChatVideoPreviewSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ChatVideoPreviewSession : ChatVideoInputSession {

    private let preview: AVCaptureVideoPreviewLayer
    
    init(_ preview: AVCaptureVideoPreviewLayer,
         _ next: VideoSessionProtocol?) {
        self.preview = preview
        super.init(videoConnection(preview), next)
    }
    
    override func start() throws {
        
        dispatch_sync_on_main {
            guard let orientation = AVCaptureVideoOrientation.Create(UIDevice.current.orientation) else { return }
            self.preview.connection.videoOrientation = orientation
        }

        try super.start()
    }
}
