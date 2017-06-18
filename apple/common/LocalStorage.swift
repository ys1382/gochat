import Foundation
import SignalProtocolC

class LocalStorage {

    enum Key: String {
        case username
        case password
        case signalClientInstallTime
        case texts

        func toData() -> Data {
            return self.rawValue.data(using: String.Encoding.utf8)!
        }

        init(_ data: Data) throws {
            guard let string = String(data: data, encoding: .utf8), let key = Key(rawValue: string) else {
                throw LocalStorageError.invalidKey
            }
            self = key
        }
    }

    enum LocalStorageError: Error {
        case invalidAddress
        case nullRecord
        case failedToLoadData
        case invalidKey
    }

    static func store(_ string: String, forKey key:Key) {
        UserDefaults.standard.set (string, forKey: key.rawValue)
    }

    static func store(_ boolean: Bool, forKey key:Key) {
        UserDefaults.standard.set(boolean, forKey: key.rawValue)
    }

    static func store(data: Data, forKey key: Key) {
        store(data: data, forKey: key.rawValue)
    }

    static func store(data: Data, forKey key: String) {
        UserDefaults.standard.set(data, forKey: key)
    }

    static func loadString(forKey key: Key) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }

    static func loadBoolean(forKey key: Key) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    // signal

    enum SignalResult {
        static let success = Int32(0)
        static let failure = Int32(99)
    }

    private static func addressToKey(_ address: UnsafePointer<signal_protocol_address>?) throws -> String {
        guard let name = address?.pointee.name, let deviceId = address?.pointee.device_id else {
            throw LocalStorageError.invalidAddress
        }
        return String(format: "%s-%d", name, deviceId)
    }

    private static func recordToData(_ record: UnsafeMutablePointer<UInt8>?, _ size: Int) throws -> Data {
        guard record != nil else {
            throw LocalStorageError.nullRecord
        }
        return Data(bytes: record!, count: size)
    }

    static func store(record: UnsafeMutablePointer<UInt8>?,
                      size: Int,
                      forAddress address:UnsafePointer<signal_protocol_address>?) throws {
        store(data: try recordToData(record, size), forKey: try addressToKey(address))
    }

    static func load(record: UnsafeMutablePointer<OpaquePointer?>?,
                     forAddress address: UnsafePointer<signal_protocol_address>?) -> Int32 {

        do {
            guard let data = UserDefaults.standard.data(forKey: try addressToKey(address)) else {
                return SignalResult.failure
            }
            let bytes = data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
                return ptr
            }
            let signalBuffer = signal_buffer_create(bytes, data.count)

            record?.pointee = signalBuffer
            return SignalResult.success

        } catch {
            return SignalResult.failure
        }
    }
}
