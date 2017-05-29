
import Foundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TRNetworkH264Serializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRNetworkH264Serializer : IODataProtocol {
    
    private var next: IODataProtocol?
    
    init(_ next: IODataProtocol?) {
        self.next = next
    }
    
    func process(_ data: [Int: NSData]) {
        let result = NSMutableData()
        
        _process(data, IOH264Part.Time, result)
        _process(data, IOH264Part.SPS, result)
        _process(data, IOH264Part.PPS, result)
        _process(data, IOH264Part.Data, result)

        next?.process([IOH264Part.NetworkPacket.rawValue: result])
    }
    
    func _process(_ data: [Int: NSData], _ part: IOH264Part, _ result: NSMutableData) {
        var size: UInt32 = UInt32(data.keys.contains(part.rawValue)
            ? data[part.rawValue]!.length
            : 0)
        
        result.append(&size, length: MemoryLayout<UInt32>.size)
        
        if (size != 0) {
            result.append(data[part.rawValue]! as Data)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TRNetworkH264Deserializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRNetworkH264Deserializer : IODataProtocol {
    
    private var next: IODataProtocol?
    
    init(_ next: IODataProtocol?) {
        self.next = next
    }

    func process(_ data: [Int: NSData]) {
        
        var shift = 0
        let packet = data[IOH264Part.NetworkPacket.rawValue]!
        var result = [Int: NSData]()

        if let part = _process(data: packet, shift: &shift) {
            result[IOH264Part.Time.rawValue] = part
        }

        if let part = _process(data: packet, shift: &shift) {
            result[IOH264Part.SPS.rawValue] = part
        }

        if let part = _process(data: packet, shift: &shift) {
            result[IOH264Part.PPS.rawValue] = part
        }

        if let part = _process(data: packet, shift: &shift) {
            result[IOH264Part.Data.rawValue] = part
        }
        
        next?.process(result)
    }
    
    func _process(data: NSData, shift: inout Int) -> NSData? {
        
        var size: UInt32 = 0
        
        data.getBytes(&size, range: NSRange(location: shift, length: MemoryLayout<UInt32>.size))
        shift += MemoryLayout<UInt32>.size
        
        if (size == 0) {
            return nil
        }

        let result = NSData(bytes: data.bytes.advanced(by: shift), length: Int(size))
        shift += Int(size)
        return result
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TRNetworkVideoSender
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class TRNetworkVideoSender : IODataProtocol {
    
    func process(_ data: [Int: NSData]) {
        Backend.shared.sendVideo(data[IOH264Part.NetworkPacket.rawValue]!)
    }
}