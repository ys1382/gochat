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
        
        dispatch_sync_on_main {
            do {
                var videoSession: AVCaptureSession.Accessor? = nil
                let orientation = AVCaptureVideoOrientation.Create(UIApplication.shared.statusBarOrientation)
                let rotated = orientation != nil ? orientation!.isPortrait : false
                let audioID = IOID(Model.shared.username!, watching)
                let videoID = audioID.groupNew()
                var audio = AV.shared.defaultAudioInput(audioID)
                var video = AV.shared.defaultVideoInput(videoID, rotated, &videoSession)
                
                if video != nil && videoSession != nil {
                    video = ChatVideoCaptureSession(videoConnection(videoSession)!,
                                                    AV.shared.defaultVideoOutputFormat!,
                                                    AVCaptureVideoOrientation.landscapeRight,
                                                    video)

                    video = ChatVideoPreviewSession(self.previewView.captureLayer,
                                                    video)
                    
                    video = VideoPreview(self.previewView.captureLayer,
                                         videoSession!,
                                         video)
                    
                    video = VideoSessionAsyncDispatcher(AV.shared.videoCaptureQueue, video!)
                }
                
                if audio != nil {
                    audio = IOSessionAsyncDispatcher(AV.shared.audioCaptureQueue, audio!)
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
        
        videoSessionStart = { (_ id: IOID, _) throws in
            self.sessionID = id.sid
            
            let result = AV.shared.defaultNetworkVideoOutput(id, VideoOutput(self.networkView.sampleLayer))
            try AV.shared.defaultIOSync(id.gid).start()
            return result
        }
        
        videoSessionStop = { (_ id: IOID) in
            self.networkView.sampleLayer.flushAndRemoveImage()
            try! AV.shared.defaultIOSync(id.gid).stop()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        start()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        try! AV.shared.startInput(nil)
    }
}
