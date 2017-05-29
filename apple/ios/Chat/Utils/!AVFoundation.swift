//
//  AVFoundation.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 29/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation
import UIKit

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
