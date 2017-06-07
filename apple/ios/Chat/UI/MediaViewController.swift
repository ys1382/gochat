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
    
    var videoSessionStart: ((_ id: IOID, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ id: IOID)->Void)?

    func setWatching(_ x: String) {
        watching = x
    }
    
    func start() {
        guard let watching = self.watching else { return }
        
        AV.shared.avCaptureQueue.async {
            do {
                var videoSession: AVCaptureSession.Factory? = nil
                let audioID = IOID(Model.shared.username!, watching)
                let videoID = audioID.groupNew()
                let audio = AV.shared.defaultAudioInput(audioID)
                var video = AV.shared.defaultVideoInput(videoID, &videoSession)
                
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
        
        videoSessionStart = { (_ id: IOID, _) in
            self.sessionID = id.sid
            return AV.shared.defaultNetworkInputVideo(id, VideoOutput(self.networkView.sampleLayer))
        }
        
        videoSessionStop = { (_) in
            self.networkView.sampleLayer.flushAndRemoveImage()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        start()
    }
}
