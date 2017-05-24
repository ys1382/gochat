
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TRVideoOutputBroadcast
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRVideoOutputBroadcast : IOVideoOutputProtocol {
 
    private let clients: [IOVideoOutputProtocol]

    init(_ clients: [IOVideoOutputProtocol]) {
        self.clients = clients
    }
    
    func start() {
        _ = clients.map({ $0.start() })
    }
    
    func process(_ data: CMSampleBuffer) {
        _ = clients.map({ $0.process(data) })
    }
    
    func stop() {
        _ = clients.map({ $0.stop() })
    }
}
