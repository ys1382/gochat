
import AVFoundation
import UIKit

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ChatVideoInputSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ChatVideoInputSession : VideoSessionProtocol {
    
    fileprivate let connection: AVCaptureConnection.Factory
    fileprivate let next: VideoSessionProtocol?
    
    init(_ connection: @escaping AVCaptureConnection.Factory,
         _ next: VideoSessionProtocol?) {
        self.connection = connection
        self.next = next
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() throws {
        try next?.start()
        
        connection()?.automaticallyAdjustsVideoMirroring = false
        connection()?.isVideoMirrored = false
        
        updateOrientation()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didRotate),
                                               name: NSNotification.Name.UIDeviceOrientationDidChange,
                                               object: nil)
    }
    
    func stop() {
        next?.stop()
        NotificationCenter.default.removeObserver(self)
    }
    
    func update(_ outputFormat: VideoFormat) throws {
        try next?.update(outputFormat)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Orientation
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    fileprivate func updateOrientation() {
        guard let orientation = AVCaptureVideoOrientation.Create(UIDevice.current.orientation) else { return }
        
        connection()!.videoOrientation = orientation
    }

    @objc fileprivate func didRotate() {
        updateOrientation()
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
            
            outputFormat.width = outputFormat.height
            outputFormat.height = outputFormat.width

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
        try next?.start()
        
        dispatch_sync_on_main {
            let orientation = AVCaptureVideoOrientation.Create(UIDevice.current.orientation)
            
            if orientation != nil {
                self.preview.connection.videoOrientation = orientation!
            }
        }
    }
    
    override func updateOrientation() {
        dispatch_sync_on_main {
            super.updateOrientation()
        }
    }
}
