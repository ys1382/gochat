
import AVFoundation

extension AVCaptureDevice {
    
    static func chatVideoDevice() -> AVCaptureDevice? {
        #if os(iOS)
            for i in AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
                if (i as! AVCaptureDevice).position == .front {
                    return i as? AVCaptureDevice
                }
            }
            
            return nil
        #else
            return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        #endif
    }
    
    var dimentions: CMVideoDimensions {
        get {
            return CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription)
        }
    }
}

private class _AVCaptureVideoPreviewLayer : AVCaptureVideoPreviewLayer {
    
    override var session: AVCaptureSession! {
        didSet {
            setNeedsLayout()
        }
    }
}

class CaptureVideoPreviewView : AppleView {
    
    #if os(iOS)
    override open class var layerClass: Swift.AnyClass {
        return _AVCaptureVideoPreviewLayer.self
    }
    #else
    override func makeBackingLayer() -> CALayer {
        return _AVCaptureVideoPreviewLayer()
    }
    #endif
    
    var captureLayer: AVCaptureVideoPreviewLayer {
        get {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

class SampleBufferDisplayView : AppleView {
    
    #if os(iOS)
    override open class var layerClass: Swift.AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    #else
    override func makeBackingLayer() -> CALayer {
        return AVSampleBufferDisplayLayer()
    }
    #endif
    
    var sampleLayer: AVSampleBufferDisplayLayer {
        get {
            
            return layer as! AVSampleBufferDisplayLayer
        }
    }
}

