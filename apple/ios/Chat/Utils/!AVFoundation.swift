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
