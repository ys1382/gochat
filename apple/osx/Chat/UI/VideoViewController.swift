import Cocoa
import AVFoundation

class VideoViewController: NSViewController {

    @IBOutlet weak var preview: CaptureVideoPreviewView!
    @IBOutlet weak var network: SampleBufferDisplayView!

    var videoSessionStart: ((_ id: IOID, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ id: IOID)->Void)?

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidLoad() {
        
        // views
        
        network.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        preview.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        // setup video output
        
        videoSessionStart = { (id: IOID, _) throws in
            self.network.sampleLayer.flushAndRemoveImage()
            return try AV.shared.startDefaultNetworkVideoOutput(id, self.network.sampleLayer)
        }

        videoSessionStop = { (id: IOID) in
            self.network.sampleLayer.flushAndRemoveImage()
            AV.shared.stopOutput(id, IOKind.Video)
        }
    }
}
