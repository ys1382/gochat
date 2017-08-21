
import Foundation

class PacketsUpdater<T> {
    
    let index: Int
    
    init() {
        self.index = 0
    }

    init(_ index: Int) {
        self.index = index
    }

    func getValue(_ data: NSData, _ value: inout T) {
        memcpy(&value, data.bytes.advanced(by: shift(data)), MemoryLayout<T>.size)
    }
    
    func setValue(_ data: inout NSData, _ value: T) {
        var copy = value
        memcpy(UnsafeMutableRawPointer(mutating: data.bytes.advanced(by: shift(data))),
               &copy,
               MemoryLayout<T>.size)
    }
    
    private func shift(_ data: NSData) -> Int {
        return PacketDeserializer(data, index).shift + MemoryLayout<UInt32>.size
    }
}

class PacketSerializer {
    
    let data = NSMutableData()
    
    func push(_ value: UnsafeRawPointer, _ size: Int) {
        var size32 = UInt32(size)
        
        data.append(&size32, length: MemoryLayout<UInt32>.size)
        data.append(value, length: size)
    }
    
    func push(data: NSData) {
        push(data.bytes, data.length)
    }

    func push(string: String) {
        push(data: string.data(using: .utf8)! as NSData)
    }
    
    func push<T>(array: [T]?) {
        var size32 = UInt32((array != nil ? array!.count : 0) * MemoryLayout<T>.size)
        
        data.append(&size32, length: MemoryLayout<UInt32>.size)
        
        guard size32 != 0 else { return }

        for var i in array! {
            data.append(&i, length: MemoryLayout<T>.size)
        }
    }
}

class PacketDeserializer {
    private let data: NSData
    private(set) var shift = 0
    
    init(_ data: NSData) {
        self.data = data
    }
    
    convenience init(_ data: NSData, _ index: Int) {
        self.init(data)
        
        for _ in 0 ..< index {
            popSkip()
        }
    }

    private func popSize() -> Int {
        var size: UInt32 = 0
        
        memcpy(&size, data.bytes.advanced(by: shift), MemoryLayout<UInt32>.size)
        shift += MemoryLayout<UInt32>.size
        
        return Int(size)
    }
    
    func pop(_ value: UnsafeMutableRawPointer) {
        let size = popSize()
        memcpy(value, data.bytes.advanced(by: shift), size)
        shift += size
    }
    
    func pop<T: InitProtocol>(array: inout [T]?) {
        let size = popSize()
        if size == 0 { return }
        var i = 0
        
        array = [T]()
        
        while i < size {
            var x = T()
            
            memcpy(&x, data.bytes.advanced(by: shift), MemoryLayout<T>.size)
            array!.append(x)
            
            i += MemoryLayout<T>.size
            shift += MemoryLayout<T>.size
        }
    }
    
    func pop(data: inout NSData?) {
        let size = popSize()
        let bytes = malloc(size)!
        
        memcpy(bytes, self.data.bytes.advanced(by: shift), Int(size))
        shift += Int(size)
        
        data = NSData(bytesNoCopy: bytes, length: size, freeWhenDone: true)
    }
    
    func popData() -> NSData {
        var result: NSData?
        pop(data: &result)
        return result!
    }
    
    func popString() -> String {
        return String(data: popData() as Data, encoding: .utf8)!
    }
    
    @discardableResult func popSkip() -> PacketDeserializer {
        shift = popSize() + shift
        return self
    }
}

protocol SerializableProtocol : InitProtocol {

    init(deserialize data: NSData)

    func ToNSData() -> NSData
}

extension SerializableProtocol {
    
    init(deserialize data: NSData) {
        self.init()
        memcpy(&self, data.bytes, MemoryLayout<Self>.size)
    }
 
    func ToNSData() -> NSData {
        var copy = self
        return NSData(bytes: &copy, length: MemoryLayout<Self>.size)
    }
}
