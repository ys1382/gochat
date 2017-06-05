
import Foundation

fileprivate class _Label {
    
    let x: String
    
    init(_ x: String) {
        self.x = x
    }
    
}

class ChatDispatchQueue {
    
    private static let key = DispatchSpecificKey<_Label>()
    
    static func CreateCheckable(_ label: String) -> DispatchQueue {
        let result = DispatchQueue(label: label)
        result.setSpecific(key: ChatDispatchQueue.key, value: _Label(label))
        return result
    }
    
    static func OnQueue(_ x: DispatchQueue) -> Bool {
        return DispatchQueue.getSpecific(key: ChatDispatchQueue.key)?.x == x.label
    }
}

func assert_main_queue() {
    assert(Thread.isMainThread)
}

func dispatch_sync_on_main(execute block: () -> Swift.Void) {
    if Thread.isMainThread {
        block()
    }
    else {
        DispatchQueue.main.sync { block() }
    }
}
