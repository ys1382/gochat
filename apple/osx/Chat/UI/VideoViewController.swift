import Cocoa
import AVFoundation

class VideoViewController: NSViewController, VideoOutputProtocol {

    @IBOutlet weak var preview: CaptureVideoPreviewView!
    @IBOutlet weak var network: SampleBufferDisplayView!

    var input: VideoInput!
    var output: VideoOutputProtocol!

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // View
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    override func viewDidAppear() {
        super.viewDidAppear()

        // start capture
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)!
        let dimention = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)

        Backend.shared.video =
            NetworkH264Deserializer(
                VideoDecoderH264(self))
        
        input = VideoInput(
            device,
            VideoEncoderH264(
                dimention,
                dimention,
                NetworkH264Serializer(
                    NetworkVideoSender())))
        
        input.start()

        // views
        
        network.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        network.sampleLayer.flush()

        preview.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
        preview.captureLayer.session = input.session
    }

    override func viewDidDisappear() {
        input.stop()
    }
    
    static var status: AVQueuedSampleBufferRenderingStatus?
    func printStatus() {
        if VideoViewController.status == .failed {
            print("AVQueuedSampleBufferRenderingStatus failed")
        }
        if let error = network.sampleLayer.error {
            print(error.localizedDescription)
        }
        if !network.sampleLayer.isReadyForMoreMediaData {
            print("Video layer not ready for more media data")
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func process(_ data: CMSampleBuffer) {
        
        if network.sampleLayer.isReadyForMoreMediaData {
            printStatus()
            network.sampleLayer.enqueue(data)
        }
    }
}
