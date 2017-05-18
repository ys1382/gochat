import Foundation

class IOChain : IOProtocol {
    static let shared = IOChain()
    private var links = [IOProtocol]()

    func register(_ io: IOProtocol) {
        links.append(io);
    }
    
    // IOProtocol

    func start() {
        _ = links.map({ $0.start() })
    }
    
    func stop() {
        _ = links.map({ $0.stop() })
    }
}
