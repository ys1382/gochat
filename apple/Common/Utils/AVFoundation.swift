
import AVFoundation

class CaptureVideoPreviewView : AppleView {
    
    #if os(iOS)
    override open class var layerClass: Swift.AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    #else
    override func makeBackingLayer() -> CALayer {
        return AVCaptureVideoPreviewLayer()
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

