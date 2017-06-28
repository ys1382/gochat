
import Foundation

class NetworkIOSessionInfo {
    let id: IOID
    let formatData: NSData.Factory?

    init(_ id: IOID) {
        self.id = id
        formatData = nil
    }
    
    init(_ id: IOID, _ format: NSData.Factory?) {
        self.id = id
        self.formatData = format
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Logs
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func logNetwork(_ message: String) {
    logMessage("Network", message)
}

func logNetworkError(_ message: String) {
    logError("Network", message)
}

func logNetworkError(_ error: Error) {
    logError("Network", error)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkInput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkInput {
    
    private var output = [String: IODataProtocol]()
    
    func add(_ sid: String, _ output: IODataProtocol) {
        self.output[sid] = output
    }
    
    func remove(_ sid: String) {
        output.removeValue(forKey: sid)
    }
    
    func removeAll() {
        self.output.removeAll()
    }
    
    func process(_ sid: String, _ data: [Int : NSData]) {
        guard output.keys.contains(sid) else { return }
        output[sid]?.process(data)
    }
}
