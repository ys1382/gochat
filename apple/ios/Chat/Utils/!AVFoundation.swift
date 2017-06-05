
import AVFoundation
import UIKit

extension AVCaptureVideoOrientation {
    
    static func Create(_ x: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch x {
        case .portrait:
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            return nil
        }
    }
}
