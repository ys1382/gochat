
import Foundation

extension JSONSerialization {
    
    static var defaultWritingOptions: JSONSerialization.WritingOptions {
        get {
            return JSONSerialization.WritingOptions.prettyPrinted
        }
    }
    
}
