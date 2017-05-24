import Cocoa
import AVFoundation

class VideoViewController: NSViewController, IOVideoOutputProtocol {

    @IBOutlet weak var preview: NSView!
    @IBOutlet weak var capture: NSView!
    @IBOutlet weak var network: NSView!

    var captureLayer = AVSampleBufferDisplayLayer()
    var previewLayer = AVCaptureVideoPreviewLayer()

    let input = TRVideoInput()
    var output: IOVideoOutputProtocol!

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidAppear() {
        super.viewDidAppear()

        captureLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        captureLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        captureLayer.videoGravity = AVLayerVideoGravityResize
        captureLayer.flush()

        previewLayer = AVCaptureVideoPreviewLayer(session: input.session)
        previewLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        previewLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        previewLayer.videoGravity = AVLayerVideoGravityResize

        self.preview.layer?.addSublayer(previewLayer)
        self.capture.layer?.addSublayer(captureLayer)
        self.network.layer?.addSublayer(networkLayer)
        
        // start capture
        
        output = TRVideoOutputBroadcast([self, TRVideoEncoderH264()])
        
        output.start()
        input.start(output)
    }

    override func viewDidDisappear() {
        input.stop()
        output.stop()
    }
    
    lazy var networkLayer: AVSampleBufferDisplayLayer = {
        var layer = AVSampleBufferDisplayLayer()
        return layer
    }()

    static var status: AVQueuedSampleBufferRenderingStatus?
    func printStatus() {
        if VideoViewController.status == .failed {
            print("AVQueuedSampleBufferRenderingStatus failed")
        }
        if let error = captureLayer.error {
            print(error.localizedDescription)
        }
        if !captureLayer.isReadyForMoreMediaData {
            print("Video layer not ready for more media data")
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOVideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start() {
        
    }
    
    func process(_ data: CMSampleBuffer) {
        
        if captureLayer.isReadyForMoreMediaData {
            printStatus()
            captureLayer.enqueue(data)
        }
    }
    
    func stop() {
        
    }

}
