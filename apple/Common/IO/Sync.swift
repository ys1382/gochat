
import Foundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOSyncBus
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IOSyncBus : IODataProtocol {
    
    private let kind: IOKind
    private let sync: IOSync
    
    init(_ kind: IOKind, _ sync: IOSync) {
        self.kind = kind
        self.sync = sync
    }
    
    func process(_ data: [Int : NSData]) {
        sync.process(kind, data)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOSync
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IOSync {
    
    private struct _TimerItem {
        
        let id: UInt64
        let kind: IOKind
        let time: Double
        let data: [Int : NSData]
        
        init(_ id: UInt64, _ kind: IOKind, _ time: Double, _ data: [Int : NSData]) {
            self.id = id
            self.kind = kind
            self.time = time
            self.data = data
        }
    }
    
    private struct _QueueItem {
        let timer: Timer
        let data: _TimerItem

        init(_ timer: Timer, _ data: _TimerItem) {
            self.timer = timer
            self.data = data
        }
    }
    
    private var id: UInt64 = 0
    private var nextID: UInt64 { get { id += 1; return id } }

    private var output = [IOKind: IODataProtocol]()
    private var timing = [IOKind: IOTimeProtocol]()
    
    private var localZero: Date?
    private var remoteZero: Double?
    private var gap: Double?
    
    private var thread: Thread?
    private var runLoop: RunLoop?
    private var queue = [UInt64: _QueueItem]()
    
    func add(_ kind: IOKind, _ time: IOTimeProtocol, _ output: IODataProtocol) {
        self.output[kind] = output
        self.timing[kind] = time
    }
    
    func process(_ kind: IOKind, _ data: [Int : NSData]) {

        if localZero == nil {
            _setup(kind, data)
        }
        else {
            _enqueue(kind, data)
        }
    }
    
    private func _gap(_ remoteTime: Double, _ localTime: Date) -> Double {
        return (remoteTime - remoteZero!) - localTime.timeIntervalSince(localZero!) - self.gap!
    }
    
    private func _setup(_ kind: IOKind, _ data: [Int : NSData]) {
        localZero = Date()
        remoteZero = timing[kind]!.time(data)
        gap = 0
        
        thread = Thread(target: self, selector: #selector(_thread), object: nil)
        thread!.start()
        
        output[kind]!.process(data)
    }
    
    private func _enqueue(_ kind: IOKind, _ data: [Int : NSData]) {
        let id = nextID
        let remoteTime = timing[kind]!.time(data)
        let localTime = Date()
        let timerItem = _TimerItem(id, kind, timing[kind]!.time(data), data)
        let gap = _gap(remoteTime, localTime)
        
        if gap < 0 {
            let timer = Timer(fireAt: localTime.addingTimeInterval(-gap),
                              interval: 0,
                              target: self,
                              selector: #selector(_process(timer:)),
                              userInfo: id,
                              repeats: false)
            
            runLoop!.add(timer, forMode: .defaultRunLoopMode)
            queue[id] = _QueueItem(timer, timerItem)
            
            logIO("sheduling \(kind) data with gap \(gap)")
        }
        else {
            self.gap! += gap
            logIO("belated \(kind) data with gap \(gap)")
            logIO("changed gap to \(self.gap!)")
            
            _process(timerItem)
        }
    }
    
    @objc func _thread() {
        runLoop = RunLoop.current
        while true {
            RunLoop.current.run()
        }
    }
    
    @objc private func _process(timer: Timer) {
        let id = timer.userInfo as! UInt64
        
        _process(queue[id]!.data)
        queue.removeValue(forKey: id)
    }
    
    private func _process(_ x: _TimerItem) {
        print("process data \(x.kind) data with id \(x.id)")
        
        AV.shared.avOutputQueue.async {
            self.output[x.kind]?.process(x.data)
        }
    }
}
