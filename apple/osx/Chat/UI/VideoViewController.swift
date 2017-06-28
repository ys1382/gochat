import Cocoa
import AVFoundation

class VideoViewController: NSViewController {

    @IBOutlet weak var preview: CaptureVideoPreviewView!
    @IBOutlet weak var network: SampleBufferDisplayView!

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidLoad() {
        
        // views
        
        network.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        preview.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
    }
}
