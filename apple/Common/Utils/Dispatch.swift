
import Foundation

fileprivate class _Label {
    
    let x: String
    
    init(_ x: String) {
        self.x = x
    }
    
}

extension DispatchQueue {

    fileprivate static let keyID = DispatchSpecificKey<_Label>()

    static func CreateCheckable(_ label: String) -> DispatchQueue {
        let result = DispatchQueue(label: label)
        result.setSpecific(key: DispatchQueue.keyID, value: _Label(label))
        return result
    }

    static func OnQueue(_ x: DispatchQueue) -> Bool {
        return DispatchQueue.getSpecific(key: DispatchQueue.keyID)?.x == x.label
    }
}

func assert(_ onQueue: DispatchQueue) {
    assert(DispatchQueue.OnQueue(onQueue))
}

func dispatch_sync_on_main(execute block: () -> Swift.Void) {
    if Thread.isMainThread {
        block()
    }
    else {
        DispatchQueue.main.sync { block() }
    }
}

func dispatch_sync_on_main(execute block: () throws -> Swift.Void) throws {
    if Thread.isMainThread {
        try block()
    }
    else {
        try DispatchQueue.main.sync { try block() }
    }
}
