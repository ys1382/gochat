
import AVFoundation
import AudioToolbox
import VideoToolbox

struct IOID {
    let from: String
    let to:   String
    let sid:  String // session unique ID
    let gid:  String // io group (audio + video) ID
    
    init(_ from: String, _ to: String, _ sid:  String, _ gid:  String) {
        self.from = from
        self.to = to
        self.sid = sid
        self.gid = gid
    }

    init(_ from: String, _ to: String) {
        self.from = from
        self.to = to
        self.sid = IOID.newID(from, to, "sid")
        self.gid = IOID.newID(from, to, "gid")
    }

    func groupNew() ->IOID {
        return IOID(from, to, IOID.newID(from, to, "sid"), gid)
    }
    
    static private func newID(_ from: String, _ to: String, _ kind: String) -> String {
        return "\(kind) \(from) - \(to) (\(UUID()))"
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Simple types
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

enum IOKind : Int {
    case Audio
    case Video
}

enum IOPart : Int {
    case Timestamp = 2 // IOTime structure
}

protocol IODataProtocol {
    
    func process(_ data: [Int: NSData])
}

protocol IOSessionProtocol {
    func start () throws
    func stop()
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
// Time
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct IOTime {
    
    let hostSeconds: Float64
    
    init() {
        hostSeconds = 0
    }
    
    init(_ hostSeconds: Float64) {
        self.hostSeconds = hostSeconds
    }
}

protocol IOTimeProtocol {
    var time: IOTime { get }
    func copy(time: IOTime) -> Self
}

protocol IOTimeSerializerProtocol {
    func time(_ data: [Int: NSData]) -> Double
    func time(_ data: inout [Int: NSData], _ time: Double)
}

class IOTimeSerializer<T: IOTimeProtocol & InitProtocol> : IOTimeSerializerProtocol {
    
    private let serializer: PacketsSerializer<T>
    
    init(_ key: Int) {
        serializer = PacketsSerializer<T>(key)
    }

    init(_ key: Int, _ shift: Int) {
        serializer = PacketsSerializer<T>(key, shift)
    }
    
    func concreteTime(_ data: [Int : NSData]) -> T {
        var result = T()
        serializer.getValue(data, &result)
        return result
    }
    
    func concreteTime(_ data: inout [Int : NSData], _ time: T) {
        serializer.setValue(&data, time)
    }
    
    func time(_ data: [Int : NSData]) -> Double {
        return concreteTime(data).time.hostSeconds
    }
    
    func time(_ data: inout [Int : NSData], _ time: Double) {
        concreteTime(&data, concreteTime(data).copy(time: IOTime(time)))
    }
}

protocol IOTimebaseProtocol {
    var zero: Double? { get set }
}

class IOTimebaseReset : IODataProtocol {
    
    private let time: IOTimeSerializerProtocol
    private var timebase: IOTimebaseProtocol
    private let next: IODataProtocol?
    
    init(_ timebase: IOTimebaseProtocol,
         _ time: IOTimeSerializerProtocol,
         _ next: IODataProtocol?) {
        self.time = time
        self.timebase = timebase
        self.next = next
    }
    
    func process(_ data: [Int : NSData]) {
        let dataTime = time.time(data)
        var copy = data
        
        if timebase.zero == nil {
            timebase.zero = dataTime
        }
        
        else if timebase.zero! > dataTime {
            assert(false)
            return
        }
        
        time.time(&copy, dataTime - timebase.zero!)
        next?.process(copy)
    }
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

func checkIO(_ x: FuncVVT) {
    do {
        try x()
    }
    catch {
        logIOError(error)
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

class IOSessionAsyncDispatcher : IOSessionProtocol {
    
    let queue: DispatchQueue
    private let next: IOSessionProtocol?
    
    init(_ queue: DispatchQueue, _ next: IOSessionProtocol?) {
        self.queue = queue
        self.next = next
    }
    
    func start() throws {
        queue.async { do { try self.next?.start() } catch { logIOError(error) } }
    }

    func stop() {
        queue.async { self.next?.stop() }
    }

}
