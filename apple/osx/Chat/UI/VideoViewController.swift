import Cocoa
import AVFoundation

class VideoViewController: NSViewController {

    @IBOutlet weak var preview: CaptureVideoPreviewView!
    @IBOutlet weak var network: SampleBufferDisplayView!

    var input: IOSessionProtocol?
    var output: VideoOutputProtocol!

    var watchingListener:((_ watching: String?)->Void)?

    let videoQueue = [CMSampleBuffer]()
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidLoad() {
        let previewLayer = preview.captureLayer
        
        // views
        
        network.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        preview.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        // setup audio/video input
        
        watchingListener = { (watching: String?) in
            AV.shared.avCaptureQueue.async {
                do {
                    if watching != nil {
                        let audio = AV.shared.defaultAudioInput(watching!)
                        let video = AV.shared.defaultVideoInput(watching!, previewLayer)
                        
                        try AV.shared.startInput(create([audio, video]));
                    }
                    else {
                        try AV.shared.startInput(nil)
                    }
                }
                catch {
                    logIOError(error)
                }
            }
        }
        
        // setup video output
        
        Backend.shared.videoSessionStart = { (_, _ sid: String, _) in
            return AV.shared.defaultNetworkInputVideo(sid, VideoOutput(self.network.sampleLayer))
        }

        Backend.shared.videoSessionStop = { (_) in
            self.network.sampleLayer.flushAndRemoveImage()
        }
    }
}
