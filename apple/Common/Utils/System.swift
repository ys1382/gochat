
import Foundation

protocol InitProtocol {
    init()
}

func typeName(_ some: Any) -> String {
    return (some is Any.Type) ? "\(some)" : "\(type(of: some))"
}

func factory<T>(_ src: T) -> () -> T {
    return { return src }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func deviceModel() -> String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0,  count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Time
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fileprivate class HostTimeInfo {
    static let shared = HostTimeInfo()
    
    let numer: UInt32
    let denom: UInt32
    
    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        
        numer = info.numer
        denom = info.denom
    }
}

func seconds2nano(_ seconds: Double) -> Int64 {
    return nano(seconds)
}

func seconds4nano(_ nano: Int64) -> Double {
    return Double(nano) / 1000000000.0
}

func milli(_ x: Double) -> Int64 {
    return Int64(x * 1000.0)
}

func micro(_ x: Double) -> Int64 {
    return Int64(x * 1000.0 * 1000.0)
}

func nano(_ x: Double) -> Int64 {
    return Int64(x * 1000.0 * 1000.0 * 1000.0)
}

func mach_absolute_seconds(_ machTime: UInt64) -> Double {
    return
        seconds4nano(
            Int64(Double(machTime * UInt64(HostTimeInfo.shared.numer)) / Double(HostTimeInfo.shared.denom)))
}

func mach_absolute_seconds() -> Double {
    return mach_absolute_seconds(mach_absolute_time())
}

func mach_absolute_time(seconds: Double) -> UInt64 {
    return
        UInt64(seconds2nano(
            seconds * Double(HostTimeInfo.shared.denom) / Double(HostTimeInfo.shared.numer)))
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Path
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension URL {
    
    static var appDocuments: URL {
        get {
            return FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        }
    }

    static var appLogs: URL {
        get {
            return URL.appDocuments.appendingPathComponent("logs")
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension NSData {
    typealias Factory = () throws -> NSData
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Stream
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension OutputStream {
    
    func write(_ x: String) {
        let data = x.utf8ToData() as NSData
        write(UnsafePointer<UInt8>(OpaquePointer(data.bytes)), maxLength: data.length)
    }
}
