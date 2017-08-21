//
//  VideoViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 29/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import UIKit
import AVFoundation

class VideoViewController : UIViewController {

    @IBOutlet weak var networkView: SampleBufferDisplayView!
    @IBOutlet weak var previewView: CaptureVideoPreviewView!
    
    var callInfo: NetworkCallInfo?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // UIViewController
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    override func viewDidLoad() {
        edgesForExtendedLayout = []
        previewView.captureLayer.videoGravity = AVLayerVideoGravityResizeAspect
        networkView.sampleLayer.videoGravity = AVLayerVideoGravityResizeAspect
    }

    override func viewDidDisappear(_ animated: Bool) {
        guard let callInfo = self.callInfo else { return }
        stopCallAsync(callInfo)
    }
}
