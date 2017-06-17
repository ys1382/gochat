import Foundation
import SignalProtocolC

class Storage {

    enum Key: String {
        case username
        case password
        case signalClientInstallTime
        case texts
    }

    enum StorageError: Error {
        case invalidAddress
        case nullRecord
        case failedToLoadData
    }

    static func store(data: Data, forKey key: Key) {
        store(data: data, forKey: key.rawValue)
    }

    static func store(data: Data, forKey key: String) {
        UserDefaults.standard.set(data, forKey: key)
    }

    func loadString(forKey key: Key) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }

    func loadBoolean(forKey key: Key) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    // signal

    private static func addressToKey(_ address: UnsafePointer<signal_protocol_address>?) throws -> String {
        guard let name = address?.pointee.name, let deviceId = address?.pointee.device_id else {
            throw StorageError.invalidAddress
        }
        return String(format: "%s-%d", name, deviceId)
    }

    private static func recordToData(_ record: UnsafeMutablePointer<UInt8>?, _ size: Int) throws -> Data {
        guard record != nil else {
            throw StorageError.nullRecord
        }
        return Data(bytes: record!, count: size)
    }

    static func store(record: UnsafeMutablePointer<UInt8>?,
                      size: Int,
                      forAddress address:UnsafePointer<signal_protocol_address>?) throws {
        store(data: try recordToData(record, size), forKey: try addressToKey(address))
    }

    static func load(record: UnsafeMutablePointer<OpaquePointer?>?,
                     forAddress address: UnsafePointer<signal_protocol_address>?) throws {
        var data = UserDefaults.standard.data(forKey: try addressToKey(address))
        if data == nil {
            throw StorageError.failedToLoadData
        }

        let start0 = UnsafeMutablePointer<UInt8>.allocate(capacity: (data?.count)!)
        data?.copyBytes(to: start0, count: (data?.count)!)

        let a = OpaquePointer(data!.bytes)

        record?.pointee = UnsafeMutableRawBufferPointer(start: data?.bytes, count: data.count)
    }
}
