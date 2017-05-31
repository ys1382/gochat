
import Foundation

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
    
    func add(_ from: String, _ output: IODataProtocol) {
        self.output[from] = output
    }
    
    func remove(_ from: String) {
        output.removeValue(forKey: from)
    }
    
    func removeAll() {
        self.output.removeAll()
    }
    
    func process(_ from: String, _ data: [Int : NSData]) {
        guard output.keys.contains(from) else { return }
        output[from]?.process(data)
    }
}
