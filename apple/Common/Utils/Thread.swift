
import Foundation

class ChatThread : Thread {
        
    var runLoop: RunLoop!
    var callbacks = [UUID: FuncVV]()
    var running: Bool = false
    
    init(_ name: String) {
        super.init()
        self.name = name
    }
    
    convenience init<T>(_ type: T) {
        self.init(typeName(type))
    }
    
    override func main() {
        runLoop = RunLoop.current
        runLoop!.add(NSMachPort(), forMode: .defaultRunLoopMode)
        running = true
        
        while running {
            runLoop!.run(until: Date().addingTimeInterval(1))
        }
    }
    
    override func start() {
        super.start()
        sync { /* wait for RunLoop initialization */ }
    }
    
    override func cancel() {
        running = false
        super.cancel()
    }
    
    func sync(_ callback: @escaping FuncVV) {
        if Thread.current == self {
            callback()
        }
        else {
            _call(callback, true)
        }
    }

    func async(_ callback: @escaping FuncVV) {
        _call(callback, false)
    }
    
    func _call(_ callback: @escaping FuncVV, _ wait: Bool) {
        let id = UUID()
        
        callbacks[id] = callback
        
        perform(#selector(_perform(_:)),
                on: self,
                with: id,
                waitUntilDone: wait)
    }

    func _perform(_ id: UUID) {
        callbacks[id]!()
        callbacks.removeValue(forKey: id)
    }
}

func assert_main() {
    assert(Thread.isMainThread)
}

