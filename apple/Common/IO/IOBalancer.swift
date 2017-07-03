
import Foundation

func logIOSync(_ message: String) {
    logIO("Sync: \(message)")
}

func logIOSyncPrior(_ message: String) {
    logIOPrior("Sync: \(message)")
}

protocol IODataBalancerProtocol {
    
    func tuning(_ data: NSData, _ gap: Double)
    func shedule(_ data: NSData, _ gap: Double, _ at: Date)
    func zombie(_ data: NSData, _ gap: Double)
    func reshedule(_ shift: Double)
}

protocol IOBalancedDataProtocol : IODataProtocol {
    
    func tuning(_ data: NSData)
    func belated(_ data: NSData)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOBalancer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IOBalancer {
    
    static let kMaxGap = 3.0 // in seconds
    static let kInterval = 0.1 // number packets for tuning
    private static let kTuneCount = 10 // number packets for tuning
    private static var kGapCount: Int = 30
    
    private var localZero: Double?
    private var remoteZero: Double?
    private var remoteLast = 0.0
    private var shedule = [Int64: Double]() // local nanoseconds : remote seconds
    
    private var gap = 0.0
    private var gapReal = 0.0
    private var gapLog = [Double]()
    
    private var packets: Int = 0
    
    private var localTime: Double {
        get {
            return Date().timeIntervalSince1970
        }
    }
    
    func process(_ remoteTime: Double,
                 shedule: @escaping FuncDDV,
                 reshedule: @escaping FuncDV,
                 zombie: @escaping FuncDV,
                 tuning: @escaping FuncDV) {
        let localTime = self.localTime
        var callback: FuncVV?
        
        packets += 1
        
        // init
        
        if localZero == nil {
            localZero = localTime
            remoteZero = remoteTime
        }
        
        // calc gap
        
        let gap = (localTime - localZero!) - (remoteTime - remoteZero!)
        let gapPrev = self.gap
        let sheduleTime = localTime + self.gap - gap
        
        _updateGap(gap)
        
        // sheduling
        
        let shedule_: FuncDV = { (time: Double) in
            shedule(self.gapReal, time)
            self.shedule[seconds2nano(sheduleTime)] = remoteTime
        }
        
        // belated
        
        if _belated(remoteTime, localTime) {
            callback = { logIOSyncPrior("global gap: \(self.gapReal)"); zombie(self.gapReal) }
        }
            
        // reshedule + shedule
            
        else if micro(gap) > micro(self.gap) {
            callback = { reshedule(self.gap - gapPrev); shedule_(sheduleTime) }
        }
            
        // shedule
            
        else {
            callback = { shedule_(sheduleTime) }
        }
        
        if packets > IOBalancer.kTuneCount {
            callback!()
        }
        else {
            tuning(self.gapReal)
        }
    }
    
    private func _belated(_ remoteTime: Double, _ localTime: Double) -> Bool {
        
        let localNano = seconds2nano(localTime)
        
        for i in shedule.keys {
            if i > localNano {
                continue
            }
            
            if remoteLast < shedule[i]! {
                remoteLast = shedule[i]!
            }
            
            shedule.removeValue(forKey: i)
        }
        
        return nano(remoteTime) <= nano(remoteLast)
    }
    
    private func _calc() -> Double {
        let gapSorted = gapLog.sorted()
        let diffAverage = max((gapSorted.last! - gapSorted.first!) / Double(gapSorted.count), IOBalancer.kInterval)
        var index: Int = gapSorted.count - 1
        
        while index >= gapSorted.count * 10 / 100 && index > 1 {
            if gapSorted[index] - gapSorted[index - 1] < diffAverage {
                break
            }
            
            index -= 1
        }
        
        return gapSorted[index]
    }
    
    private func _updateGap(_ gap: Double) {
        gapLog.append(gap)
        
        if gapLog.count > IOBalancer.kGapCount {
            gapLog.removeFirst()
        }
        
        self.gapReal = _calc()
        self.gap = min(gapReal, IOBalancer.kMaxGap) + IOBalancer.kInterval
        
        logIOSync("gap \(self.gap)")
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IOSheduler
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IOSheduler : IODataBalancerProtocol, IOSessionProtocol {
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Internal Structs
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    private struct _QueueItem {
        var timer: Timer
        let data: NSData
        
        init(_ timer: Timer, _ data: NSData) {
            self.timer = timer
            self.data = data
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Fields
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    private(set) var active: Bool = false
    
    private var id: Int = 0
    private var nextID: Int { get { id += 1; return id } }
    
    private var thread: ChatThread?
    private var queue = [Int: _QueueItem]()
    
    private let kind: IOKind
    private let output: IOBalancedDataProtocol
    
    init(_ kind: IOKind, _ output: IOBalancedDataProtocol) {
        self.kind = kind
        self.output = output
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOSessionProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func start() throws {
        guard active == false else { return }
        
        thread = ChatThread(IOSheduler.self)
        thread!.start()
        active = true
    }
    
    func stop() {
        guard active == true else { return }
        
        thread!.cancel()
        thread = nil
        active = false
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOBalancedDataProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func tuning(_ data: NSData, _ gap: Double) {
        output.tuning(data)
    }
    
    func shedule(_ data: NSData, _ gap: Double, _ at: Date) {
        thread!.sync {
            let id = self.nextID
            let timer = self._timer(at, id)

            logIOSync("Sheduling \(self.kind) data with id \(id)")
            self.queue[id] = _QueueItem(timer, data)
            self.sheduleTimer(timer)
        }
    }
    
    func zombie(_ data: NSData, _ gap: Double) {
        logIOSyncPrior("Belated \(self.kind) data with gap \(gap) lost")
        output.belated(data)
    }
    
    func reshedule(_ shift: Double) {
        thread!.sync {
            logIOSync("Resheduling with shift \(shift)")

            for var i in self.queue {
                i.value.timer.invalidate()
                i.value.timer = self._timer(i.value.timer.fireDate.addingTimeInterval(shift),
                                            i.key)
                self.sheduleTimer(i.value.timer)
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Sheduling
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func _timer(_ at: Date, _ id: Int) -> Timer {
        return Timer(fireAt: at,
                     interval: 0,
                     target: self,
                     selector: #selector(_output(timer:)),
                     userInfo: id,
                     repeats: false)
    }
    
    @objc private func _output(timer: Timer) {
        let id = timer.userInfo as! Int
        
//        assert(queue[id] != nil)
        guard let data = queue[id]?.data else { return }
        
        _output(data)
        queue.removeValue(forKey: id)
    }
    
    private func _output(_ data: NSData) {
        AV.shared.avOutputQueue.async {
            self.output.process(data)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Test support
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    fileprivate func sheduleTimer(_ timer: Timer) {
        thread!.runLoop.add(timer, forMode: .defaultRunLoopMode)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Utils
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class IOBalanceSubdataSkip : IOBalancedDataProtocol {
    
    let next: IODataProtocol?
    
    init(_ next: IODataProtocol?) {
        self.next = next
    }
    
    func tuning(_ data: NSData) {
    }
    
    func belated(_ data: NSData) {
    }
    
    func process(_ data: NSData) {
        next?.process(data)
    }
}

class IOBalancedDataSession : IODataSession, IOBalancedDataProtocol {
    
    let next: IOBalancedDataProtocol
    
    init(_ next: IOBalancedDataProtocol) {
        self.next = next
        super.init(next)
    }
    
    func tuning(_ data: NSData) {
        guard active else { logIO("received data after session stopped"); return }
        next.tuning(data)
    }
    
    func belated(_ data: NSData) {
        guard active else { logIO("received data after session stopped"); return }
        next.belated(data)
    }
}

class IODataAdapter4Balancer : IODataProtocol {
    
    private let balancer: IOBalancer
    private let time: IOTimeUpdaterProtocol
    private let output: IODataBalancerProtocol
    
    init(_ time: IOTimeUpdaterProtocol, _ balancer: IOBalancer, _ output: IODataBalancerProtocol) {
        self.time = time
        self.output = output
        self.balancer = balancer
    }
    
    func process(_ data: NSData) {
        let remoteTime = time.time(data)
        
        balancer.process(remoteTime,
                         shedule: { (gap: Double, at: Double) in
                            self.output.shedule(data, gap, Date(timeIntervalSince1970: at)) },
                         reshedule: { (shift: Double) in self.output.reshedule(shift) },
                         zombie: { (gap: Double) in self.output.zombie(data, gap) },
                         tuning: { (gap: Double) in self.output.tuning(data, gap) })
    }
}

class IODataBalancer: IODataBalancerProtocol {
    
    func tuning(_ data: NSData, _ gap: Double) { }
    func shedule(_ data: NSData, _ gap: Double, _ at: Date) {}
    func zombie(_ data: NSData, _ gap: Double) {}
    func reshedule(_ shift: Double) {}
}

class IODataBalancerBroadcast : IODataBalancerProtocol {
    
    var x: [IODataBalancerProtocol?]
    
    init(_ x: [IODataBalancerProtocol?]) {
        self.x = x
    }
    
    func tuning(_ data: NSData, _ gap: Double) {
        _ = x.map({ $0?.tuning(data, gap) })
    }
    
    func shedule(_ data: NSData, _ gap: Double, _ at: Date) {
        _ = x.map({ $0?.shedule(data, gap, at) })
    }
    
    func zombie(_ data: NSData, _ gap: Double) {
        _ = x.map({ $0?.zombie(data, gap) })
    }
    
    func reshedule(_ shift: Double) {
        _ = x.map({ $0?.reshedule(shift) })
        
    }
}

