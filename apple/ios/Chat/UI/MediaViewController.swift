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

    private let input = VideoInput(AVCaptureDevice.frontCamera())
    private var output: VideoOutputProtocol!

    @IBOutlet weak var videoView: SampleBufferDisplayView!
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UIViewController
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    override func viewDidLoad() {
        self.edgesForExtendedLayout = []
    }

    override func viewWillAppear(_ animated: Bool) {
       
        // views
        
        previewView.captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewView.captureLayer.session = input.session
        
        // start capture
        
        output =
            VideoEncoderH264(
                NetworkH264Serializer(NetworkVideoSender()))
        
        Backend.shared.video =
            NetworkH264Deserializer(
                VideoDecoderH264(self))
        
        input.start(output)
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
