
import AVFoundation

extension AVCaptureDeviceFormat {
    
    var dimensions: CMVideoDimensions {
        get {
            return CMVideoFormatDescriptionGetDimensions(formatDescription)
        }
    }
    
    var mediaSubtype:FourCharCode {
        get {
            return CMFormatDescriptionGetMediaSubType(formatDescription)
        }
    }
}

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
    
    func inputFormat(width: Int32) -> AVCaptureDeviceFormat? {
        
        var result: AVCaptureDeviceFormat? = nil
        var diff: Int32 = 0
        
        for ii in formats {
            let i = ii as! AVCaptureDeviceFormat
            let i_diff = Int32(width) - i.dimensions.width

            if result == nil || abs(diff) > abs(i_diff) {
                result = i
                diff = i_diff
            }
        }
        
        return result
    }

    func inputFormat(height: Int32) -> AVCaptureDeviceFormat? {
        
        var result: AVCaptureDeviceFormat? = nil
        var diff: Int32 = 0
        
        for ii in formats {
            let i = ii as! AVCaptureDeviceFormat
            let i_diff = Int32(height) - i.dimensions.height
            
            if result == nil || abs(diff) > abs(i_diff) {
                result = i
                diff = i_diff
            }
        }
        
        return result
    }
}

extension AVCaptureConnection {
    
    typealias Accessor = ((AVCaptureConnection) throws -> Void) throws -> Void
}

extension AVCaptureSession {
    
    typealias Accessor = ((AVCaptureSession) throws -> Void) throws -> Void
}

extension AVCaptureVideoOrientation {

    var isPortrait: Bool {
        get {
            return self == AVCaptureVideoOrientation.portrait || self == AVCaptureVideoOrientation.portraitUpsideDown
        }
    }
    
    var isLandscape: Bool {
        get {
            return self == AVCaptureVideoOrientation.landscapeLeft || self == AVCaptureVideoOrientation.landscapeRight
        }
    }
    
    func rotates(_ to: AVCaptureVideoOrientation) -> Bool {
        if self.isLandscape && to.isPortrait {
            return true
        }
        
        if self.isPortrait && to.isLandscape {
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

func videoConnection(_ layer: AVCaptureVideoPreviewLayer) -> AVCaptureConnection.Accessor {
    return { (_ x: (AVCaptureConnection) throws -> Void) in
        try x(layer.connection)
    }
}

func videoConnection(_ session: AVCaptureSession.Accessor?) -> AVCaptureConnection.Accessor? {
    return { (_ x: (AVCaptureConnection) throws -> Void) in
        try session?({ (_ session: AVCaptureSession) throws in
            guard let output = session.outputs.first as? AVCaptureOutput else { return }
            guard let _ = output.connections.first else { return }

            try x(output.connection(withMediaType: AVMediaTypeVideo))
        })
    }
}
