//
//  MediaViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 29/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import UIKit
import AVFoundation

extension AVCaptureDevice {
    
    class func frontCamera() -> AVCaptureDevice? {
        
        for i in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
            if (i as! AVCaptureDevice).position == .front {
                return i as? AVCaptureDevice
            }
        }

        return nil
    }
}

extension UIView {
    
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable var borderColor: UIColor? {
        get {
            return UIColor(cgColor: layer.borderColor!)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }
}

class CaptureVideoPreviewView : UIView {
    
    override open class var layerClass: Swift.AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var captureLayer: AVCaptureVideoPreviewLayer {
        get {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

class SampleBufferDisplayView : UIView {
    
    override open class var layerClass: Swift.AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    var sampleLayer: AVSampleBufferDisplayLayer {
        get {
            return layer as! AVSampleBufferDisplayLayer
        }
    }
}

class MediaViewController : UIViewController, IOVideoOutputProtocol {

    private let input = TRVideoInput(AVCaptureDevice.frontCamera())
    private var output: IOVideoOutputProtocol!

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
            TRVideoEncoderH264(
                TRNetworkH264Serializer(TRNetworkVideoSender()))
        
        Backend.shared.video =
            TRNetworkH264Deserializer(
                TRVideoDecoderH264(self))
        
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
