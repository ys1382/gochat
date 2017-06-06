
import Foundation

class IOSync {
    
    private let master: IOKind
    private var output = [IOKind: IODataProtocol]()
    
    init(_ master: IOKind) {
        self.master = master
    }
    
    func add(_ kind: IOKind, _ output: IODataProtocol) {
        self.output[kind] = output
    }
    
    func process(_ kind: IOKind, _ time: IOTimeProtocol, _ data: [Int : NSData]) {
        output[kind]?.process(data)
    }
}

class IOSyncBus : IODataProtocol {
    
    private let kind: IOKind
    private let time: IOTimeProtocol
    private let sync: IOSync
    
    init(_ kind: IOKind, _ time: IOTimeProtocol, _ sync: IOSync) {
        self.kind = kind
        self.time = time
        self.sync = sync
    }
    
    func process(_ data: [Int : NSData]) {
        sync.process(kind, time, data)
    }
}
