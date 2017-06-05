import Cocoa
import AVFoundation

class VideoViewController: NSViewController, VideoOutputProtocol {

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
        
        Backend.shared.videoSessionStart = { (_, _) in
            return AV.shared.defaultNetworkInputVideo(self)
        }

        Backend.shared.videoSessionStop = { (_) in
            self.network.sampleLayer.flushAndRemoveImage()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
     
        // views

        network.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        preview.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
    }

    func printStatus() {
        if network.sampleLayer.status == .failed {
            logIO("AVQueuedSampleBufferRenderingStatus failed")
        }
        if let error = network.sampleLayer.error {
            logIO(error.localizedDescription)
        }
        if !network.sampleLayer.isReadyForMoreMediaData {
            logIO("Video layer not ready for more media data")
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func process(_ data: CMSampleBuffer) {
        
        assert_av_output_queue()
        
        DispatchQueue.main.sync {
            if network.sampleLayer.isReadyForMoreMediaData {
                network.sampleLayer.enqueue(data)
            }
            else {
                printStatus()
                network.sampleLayer.flush()
            }
        }
    }
}
