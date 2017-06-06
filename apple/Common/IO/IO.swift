
import AVFoundation
import AudioToolbox
import VideoToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simple types
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

enum IOKind : Int {
    case Audio
    case Video
}

protocol IODataProtocol {
    
    func process(_ data: [Int: NSData])
}

protocol IOSessionProtocol {
    func start () throws
    func stop()
}

protocol IOTimeProtocol {
    func time(_ data: [Int: NSData]) -> Double
}

class IOData : IODataProtocol {
    private let next: IODataProtocol?
    init() { next = nil }
    init(_ next: IODataProtocol?) { self.next = next }
    func process(_ data: [Int : NSData]) { next?.process(data) }
}

class IOSession : IOSessionProtocol {
    private let next: IOSessionProtocol?
    init() { next = nil }
    init(_ next: IOSessionProtocol?) { self.next = next }
    func start() throws { try next?.start() }
    func stop() { next?.stop() }
}

class IOSessionBroadcast : IOSessionProtocol {
    
    private var x: [IOSessionProtocol?]
    
    init(_ x: [IOSessionProtocol?]) {
        self.x = x
    }
    
    func start () throws {
        _ = try x.map({ try $0?.start() })
    }
    
    func stop() {
        _ = x.reversed().map({ $0?.stop() })
    }
}

func create(_ x: [IOSessionProtocol?]) -> IOSessionProtocol? {
    if (x.count == 0) {
        return nil
    }
    if (x.count == 1) {
        return x.first!
    }
    
    return IOSessionBroadcast(x)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

enum ErrorIO : Error {
    case Error(String)
}

func logIO(_ message: String) {
    logMessage("IO", message)
}

func logIOError(_ error: Error) {
    logError("IO", error)
}

func logIOError(_ error: String) {
    logError("IO", error)
}

func checkStatus(_ status: OSStatus, _ message: String) throws {
    guard status == 0 else {
        throw ErrorIO.Error(message + ", status code \(status)")
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOData dispatcher
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IODataDispatcher : IODataProtocol {
    
    let queue: DispatchQueue
    let next: IODataProtocol
    
    init(_ queue: DispatchQueue, _ next: IODataProtocol) {
        self.queue = queue
        self.next = next
    }
    
    func process(_ data: [Int : NSData]) {
        queue.sync { self.next.process(data) }
    }
    
}
