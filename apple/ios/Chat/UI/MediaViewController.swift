//
//  MediaViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 29/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import UIKit
import AVFoundation

class MediaViewController : UIViewController {

    private(set) var sessionID = String()
    private var watching: String?

    @IBOutlet weak var networkView: SampleBufferDisplayView!
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    
    var videoSessionStart: ((_ to: String, _ sid: String, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ sid: String)->Void)?

    func setWatching(_ x: String) {
        watching = x
    }
    
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
        networkView.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
        
        // setup video output
        
        videoSessionStart = { (_, _ sid: String, _) in
            self.sessionID = sid
            return AV.shared.defaultNetworkInputVideo(sid, VideoOutput(self.networkView.sampleLayer))
        }
        
        videoSessionStop = { (_) in
            self.networkView.sampleLayer.flushAndRemoveImage()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        start()
    }
}
