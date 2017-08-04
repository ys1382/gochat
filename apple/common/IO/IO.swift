
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

protocol IODataProtocol {
    
    func process(_ data: NSData)
}

typealias IOSessionProtocol = SessionProtocol

struct IOFormat {
    
    private static let kID = "kID"

    var data: [String: Any]

    init () {
        data = [String: Any]()
        data[IOFormat.kID] = UUID().uuidString
    }
    
    init(_ data: [String: Any]) {
        self.data = data
    }
    
    var id: String {
        get {
            return data[IOFormat.kID]! as! String
        }
    }
}

class IOData : IODataProtocol {
    private let next: IODataProtocol?
    init() { next = nil }
    init(_ next: IODataProtocol?) { self.next = next }
    func process(_ data: NSData) { next?.process(data) }
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

func broadcast(_ x: [IOSessionProtocol?]) -> IOSessionProtocol? {
    if (x.count == 0) {
        return nil
    }
    if (x.count == 1) {
        return x.first!
    }
    
    return IOSessionBroadcast(x)
}

class IODataSession : IODataProtocol, IOSessionProtocol {
    
    private(set) var active = false
    private let next: IODataProtocol
    
    init(_ next: IODataProtocol) {
        self.next = next
    }
    
    func start() throws {
        assert(active == false)
        active = true
    }
    
    func stop() {
        assert(active == true)
        active = false
    }
    
    func process(_ data: NSData) {
        guard active else { logIO("received data after session stopped"); return }
        next.process(data)
    }
}

struct IOInputContext {
    let qos: IOQoS
    let balancer: IOQoSBalancerProtocol

    init(_ balancer: IOQoSBalancerProtocol) {
        self.qos = IOQoS()
        self.balancer = balancer
    }
}

struct IOOutputContext {
    let id: IOID?
    let session: IOSessionProtocol?
    let data: IODataProtocol?
    let timebase: IOTimebase?
    let balancer: IOBalancer?
    
    // concrete context
    init(_ id: IOID?,
         _ session: IOSessionProtocol?,
         _ data: IODataProtocol?,
         _ timebase: IOTimebase?,
         _ balancer: IOBalancer?) {
        self.id = id
        self.session = session
        self.data = data
        self.timebase = timebase
        self.balancer = balancer
    }
    
    // create context with shared info
    init(_ id: IOID,
         _ session: IOSessionProtocol,
         _ data: IODataProtocol,
         _ context: IOOutputContext) {
        self.init(id, session, data, context.timebase, context.balancer)
    }
    
    // context for sharing sync and balancer
    init() {
        self.init(nil, nil, nil, IOTimebase(), IOBalancer())
    }
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

protocol IOTimeUpdaterProtocol {
    func time(_ data: NSData) -> Double
    func time(_ data: inout NSData, _ time: Double)
}

class IOTimeUpdater<T: IOTimeProtocol & InitProtocol> : IOTimeUpdaterProtocol {
    
    private let updater: PacketsUpdater<T>
    
    init(_ index: Int) {
        updater = PacketsUpdater<T>(index)
    }
    
    func concreteTime(_ data: NSData) -> T {
        var result = T()
        updater.getValue(data, &result)
        return result
    }
    
    func concreteTime(_ data: inout NSData, _ time: T) {
        updater.setValue(&data, time)
    }
    
    func time(_ data: NSData) -> Double {
        return concreteTime(data).time.hostSeconds
    }
    
    func time(_ data: inout NSData, _ time: Double) {
        concreteTime(&data, concreteTime(data).copy(time: IOTime(time)))
    }
}

class IOTimebase {
    var zero: Double?
}

class IOTimebaseReset : IODataProtocol {
    
    private let time: IOTimeUpdaterProtocol
    private var timebase: IOTimebase
    private let next: IODataProtocol?
    
    init(_ timebase: IOTimebase,
         _ time: IOTimeUpdaterProtocol,
         _ next: IODataProtocol?) {
        self.time = time
        self.timebase = timebase
        self.next = next
    }
    
    func process(_ data: NSData) {
        let dataTime = time.time(data)
        var copy = data
        
        if timebase.zero == nil {
            timebase.zero = dataTime
        }
        
        else if timebase.zero! > dataTime {
            return
        }
        
        time.time(&copy, dataTime - timebase.zero!)
        next?.process(copy)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// QOS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

protocol IOQoSProtocol {
    func change(_ toQID: String, _ diff: Int)
}

protocol IOQoSBalancerProtocol {
    func process(_ qosID: String, _ gap: Double)
}

class IOQoSDispatcher : IOQoSProtocol {
    
    let queue: DispatchQueue
    let next: IOQoSProtocol
    
    init(_ queue: DispatchQueue, _ next: IOQoSProtocol) {
        self.queue = queue
        self.next = next
    }
    
    func change(_ toQID: String, _ diff: Int) {
        queue.sync { next.change(toQID, diff) }
    }
    
}

class IOQoSBroadcast : IOQoSProtocol {
    
    private var x: [IOQoSProtocol?]
    
    init(_ x: [IOQoSProtocol?]) {
        self.x = x
    }
    
    func change(_ toQID: String, _ diff: Int) {
        _ = x.map({ $0?.change(toQID, diff) })
    }
}

class IOQoS {
    
    static let kInit = 0
    static let kIncrease = 1
    static let kDecrease = -1
    
    var clients = [IOQoSProtocol]()
    var qid: String = UUID().uuidString

    func add(_ x: IOQoSProtocol) {
        clients.append(x)
        x.change(qid, IOQoS.kInit)
    }
    
    func change(_ diff: Int) {
        qid = UUID().uuidString
        _ = clients.map({ $0.change(qid, diff) })
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

func logIOPrior(_ message: String) {
    logPrior("IO", message)
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

class IODataAsyncDispatcher : IODataProtocol {
    
    let queue: DispatchQueue
    private let next: IODataProtocol
    
    init(_ queue: DispatchQueue, _ next: IODataProtocol) {
        self.queue = queue
        self.next = next
    }
    
    func process(_ data: NSData) {
        queue.async { self.next.process(data) }
    }
}

class IOSessionDispatcher : IOSessionProtocol {
    typealias Call = (@escaping FuncVV) -> Void
    
    private let call: Call
    private let next: IOSessionProtocol?

    init(_ call: @escaping Call, _ next: IOSessionProtocol?) {
        self.call = call
        self.next = next
    }
    
    func start() throws {
        call { do { try self.next?.start() } catch { logIOError(error) } }
    }
    
    func stop() {
        call { self.next?.stop() }
    }
}

class IOSessionSyncDispatcher : IOSessionDispatcher {
    
    let queue: DispatchQueue
    
    init(_ queue: DispatchQueue, _ next: IOSessionProtocol?) {
        self.queue = queue
        super.init({ (block: @escaping FuncVV) in queue.sync(execute: block) }, next)
    }
}

class IOSessionAsyncDispatcher : IOSessionDispatcher {
    
    let queue: DispatchQueue
    
    init(_ queue: DispatchQueue, _ next: IOSessionProtocol?) {
        self.queue = queue
        super.init({ (block: @escaping FuncVV) in queue.async(execute: block) }, next)
    }
}
