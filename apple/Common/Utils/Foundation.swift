
import Foundation

extension JSONSerialization {
    
    static var defaultWritingOptions: JSONSerialization.WritingOptions {
        get {
            return JSONSerialization.WritingOptions.prettyPrinted
        }
    }
    
}

extension Array where Element: AnyObject {
    mutating func remove(_ object: Element) {
        if let index = index(where: { object === $0 }) {
            remove(at: index)
        }
    }
}

protocol BroadcastProtocol {
    init<T>(_ x: [T?])
}

extension BroadcastProtocol {
    
    static func Create<T>(_ x: [T]) -> T? {
        if (x.count == 0) {
            return nil
        }
        if (x.count == 1) {
            return x.first
        }
        
        return self.init(x) as? T
    }
}
