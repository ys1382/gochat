import Cocoa
import AVFoundation

class VideoViewController: NSViewController, VideoOutputProtocol {

    @IBOutlet weak var preview: NSView!
    @IBOutlet weak var capture: NSView!
    @IBOutlet weak var network: NSView!

    var captureLayer = AVSampleBufferDisplayLayer()
    var previewLayer = AVCaptureVideoPreviewLayer()

    var input: VideoInput!
    var output: VideoOutputProtocol!

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidAppear() {
        super.viewDidAppear()

        // start capture
        
        Backend.shared.video =
            NetworkH264Deserializer(
                VideoDecoderH264(self))
        
        input = VideoInput(
            VideoEncoderH264(
                NetworkH264Serializer(
                    NetworkVideoSender())))
        
        input.start(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice)

        // views
        
        captureLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        captureLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        captureLayer.videoGravity = AVLayerVideoGravityResize
        captureLayer.flush()

        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        previewLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        previewLayer.videoGravity = AVLayerVideoGravityResize
        previewLayer.session = input.session

        self.preview.layer?.addSublayer(previewLayer)
        self.capture.layer?.addSublayer(captureLayer)
        self.network.layer?.addSublayer(networkLayer)
    }

    override func viewDidDisappear() {
        input.stop()
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
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func process(_ data: CMSampleBuffer) {
        
        if captureLayer.isReadyForMoreMediaData {
            printStatus()
            captureLayer.enqueue(data)
        }
    }
}
