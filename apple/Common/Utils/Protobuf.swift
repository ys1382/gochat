
import Foundation
import ProtocolBuffers

#if os(iOS)
public protocol GeneratedEnum:RawRepresentable, CustomDebugStringConvertible, CustomStringConvertible, Hashable {
    func toString() -> String
    static func fromString(_ str:String) throws -> Self
}
#endif
