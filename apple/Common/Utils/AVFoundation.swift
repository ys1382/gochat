
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

extension AVCaptureConnection {
    
    typealias Factory = () -> AVCaptureConnection?
}

extension AVCaptureSession {
    
    typealias Factory = () -> AVCaptureSession?
}

extension AVCaptureVideoOrientation {

    func isPortrait() -> Bool {
        return self == AVCaptureVideoOrientation.portrait || self == AVCaptureVideoOrientation.portraitUpsideDown
    }
    
    func isLandscape() ->Bool {
        return self == AVCaptureVideoOrientation.landscapeLeft || self == AVCaptureVideoOrientation.landscapeRight
    }
    
    func rotates(_ to: AVCaptureVideoOrientation) -> Bool {
        if self.isLandscape() && to.isPortrait() {
            return true
        }
        
        if self.isPortrait() && to.isLandscape() {
            return true
        }
        
        return false
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

func videoConnection(_ layer: AVCaptureVideoPreviewLayer) -> AVCaptureConnection.Factory {
    return { () in
        return layer.connection
    }
}

func videoConnection(_ session_: AVCaptureSession.Factory?) -> AVCaptureConnection.Factory? {
    return { () in
        guard let session = session_?() else { return nil }
        guard let output = session.outputs.first as? AVCaptureOutput else { return nil }
        guard let _ = output.connections.first else { return nil }
        
        return output.connection(withMediaType: AVMediaTypeVideo)
    }
}
