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
            dispatch_sync_on_main {
                do {
                    if watching != nil {
                        let audioID = IOID(Model.shared.username!, watching!)
                        let videoID = audioID.groupNew()
                        let audio =
                            IOSessionAsyncDispatcher(
                                AV.shared.audioCaptureQueue,
                                AV.shared.defaultAudioInput(audioID))
                        let video =
                            VideoSessionAsyncDispatcher(
                                AV.shared.videoCaptureQueue,
                                AV.shared.defaultVideoInput(videoID, previewLayer))
                        
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
        
        Backend.shared.videoSessionStart = { (_ id: IOID, _) in
            let result = AV.shared.defaultNetworkVideoOutput(id, VideoOutput(self.network.sampleLayer))
            try! AV.shared.defaultIOSync(id.gid).start()
            return result
        }

        Backend.shared.videoSessionStop = { (_) in
            self.network.sampleLayer.flushAndRemoveImage()
        }
    }
}
