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

    private var videoInp: VideoInput!

    var audioOut: AudioOutput!
    var audioInp: AudioInput!

    @IBOutlet weak var videoView: SampleBufferDisplayView!
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UIViewController
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    override func viewDidLoad() {
        self.edgesForExtendedLayout = []
    }

    override func viewWillAppear(_ animated: Bool) {
       
        // start video capture
        
        Backend.shared.video =
            NetworkH264Deserializer(
                VideoDecoderH264(
                    self))
        
        videoInp =
            VideoInput(
                VideoEncoderH264(
                    NetworkH264Serializer(
                        NetworkVideoSender())))

        videoInp.start(AVCaptureDevice.frontCamera())

        // start audio capture
        
        audioOut =
            AudioOutput()

        Backend.shared.audio =
            NetworkAACDeserializer(
                audioOut)

        audioInp =
            AudioInput(
                NetworkAACSerializer(
                    NetworkAudioSender()))
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! AVAudioSession.sharedInstance().setActive(true)
        audioInp.start(kAudioFormatMPEG4AAC, 0.1)
        audioOut.start(&audioInp.format!, audioInp.packetMaxSize, 0.1)
        
        // views
        
        previewView.captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewView.captureLayer.session = videoInp.session
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
