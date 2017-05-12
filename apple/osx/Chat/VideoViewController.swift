import Cocoa
import AVFoundation

class VideoViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var preview: NSView!
    @IBOutlet weak var capture: NSView!
    @IBOutlet weak var network: NSView!

    var captureLayer = AVSampleBufferDisplayLayer()
    var previewLayer = AVCaptureVideoPreviewLayer()
    let audioDelegate = Audio()
    let videoDelegate = Video()

    func handleSample(_ sampleBuffer: CMSampleBuffer) {
        if captureLayer.isReadyForMoreMediaData {
            printStatus()
            captureLayer.enqueue(sampleBuffer)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        videoDelegate.start(videoCallback: handleSample)
//        audioDelegate.start()

        captureLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        captureLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        captureLayer.videoGravity = AVLayerVideoGravityResize
        captureLayer.flush()

        previewLayer = AVCaptureVideoPreviewLayer(session: videoDelegate.cameraSession)
        previewLayer.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        previewLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        previewLayer.videoGravity = AVLayerVideoGravityResize

        self.preview.layer?.addSublayer(previewLayer)
        self.capture.layer?.addSublayer(captureLayer)
        self.network.layer?.addSublayer(networkLayer)
//        let h = Haishin()
//        h.start(view: self.network)
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
}
