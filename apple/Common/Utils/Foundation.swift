
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
