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
        
        if watching != nil {
            AV.shared.avCaptureQueue.async {
                do {
                    try AV.shared.startInput(AV.shared.defaultAudioVideoInput(self.watching!,
                                                                              self.previewView.captureLayer));
                }
                catch {
                    logIOError(error)
                }
            }
        }
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
