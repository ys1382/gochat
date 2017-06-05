//
//  MediaViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 29/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import UIKit
import AVFoundation

class MediaViewController : UIViewController, VideoOutputProtocol {

    var watching: String?

    @IBOutlet weak var videoView: SampleBufferDisplayView!
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    
    var videoSessionStart: ((_ sid: String, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ sid: String)->Void)?

    func start() {
        guard let watching = self.watching else { return }
        
        AV.shared.avCaptureQueue.async {
            do {
                var videoSession: AVCaptureSession.Factory? = nil
                let audio = AV.shared.defaultAudioInput(watching)
                var video = AV.shared.defaultVideoInput(watching, &videoSession)
                
                if video != nil && videoSession != nil {
                    video = ChatVideoCaptureSession(videoConnection(videoSession)!,
                                                    AV.shared.defaultVideoOutputFormat(),
                                                    AVCaptureVideoOrientation.landscapeRight,
                                                    video)

                    video = ChatVideoPreviewSession(self.previewView.captureLayer,
                                                    video)
                    
                    video = VideoPreview(self.previewView.captureLayer,
                                         videoSession!,
                                         video)
                }
                
                try AV.shared.startInput(create([audio, video]));
            }
            catch {
                logIOError(error)
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UIViewController
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    override func viewDidLoad() {
        edgesForExtendedLayout = []
        previewView.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
        videoView.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        // setup video output
        
        videoSessionStart = { (_, _) in
            return AV.shared.defaultNetworkInputVideo(self)
        }
        
        videoSessionStop = { (_) in
            self.videoView.sampleLayer.flushAndRemoveImage()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        // start video capture
        
        start()
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOVideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func process(_ data: CMSampleBuffer) {
        
        if videoView.sampleLayer.isReadyForMoreMediaData {
            videoView.sampleLayer.enqueue(data)
        }
    }

}
