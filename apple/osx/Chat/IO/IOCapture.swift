import AVFoundation

class IOCapture : IOProtocol {
    
    private var session: AVCaptureSession!
    
    init(_ session: AVCaptureSession) {
        self.session = session;
    }
    
    func start() {
        session.startRunning()
    }
    
    func stop() {
        session.stopRunning()
    }
}
