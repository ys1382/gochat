import Foundation
import SignalProtocolC

class LocalStorage {

    private static var addressRecords = [SignalProtocolAddress: Data]()
    private static var addressIdentityKeys = [SignalProtocolAddress: Data]()
    private static var addressKeys = [SignalProtocolAddress: Data]()
    private static var addresses = [Data: [SignalProtocolAddress]]()
    private static var preKeyRecords = [UInt32: Data]()
    private static var signedPreKeyRecords = [UInt32: Data]()

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
        static let success      = Int32(0)
        static let failure      = Int32(-99)
        static let exists       = Int32(1)
        static let doesNotExist = Int32(0)
    }

    class SignalProtocolAddress : Hashable {
        let address: signal_protocol_address
        let name: Data

        init(_ address: signal_protocol_address) {
            self.address = address
            self.name = SignalProtocolAddress.nameFor(address.name, address.name_len)
        }

        static func nameFor(_ name: UnsafePointer<Int8>, _ nameLen: Int) -> Data {
            return Data(bytes: name, count: nameLen)
        }

        var hashValue: Int {
            return address.name.hashValue + address.device_id.hashValue
        }

        static func == (lhs: SignalProtocolAddress, rhs: SignalProtocolAddress) -> Bool {
            return lhs.name == rhs.name && lhs.address.device_id == rhs.address.device_id
        }
    }

    private static func addressToKey(_ address: UnsafePointer<signal_protocol_address>?) throws -> String {
        guard let name = address?.pointee.name, let deviceId = address?.pointee.device_id else {
            throw LocalStorageError.invalidAddress
        }
        return String(format: "%s-%d", name, deviceId)
    }

    private static func recordToData(_ record: UnsafeMutablePointer<UInt8>?, _ size: Int) -> Data {
        return Data(bytes: record!, count: size)
    }

    private static func fetchRecord(forAddress address:UnsafePointer<signal_protocol_address>?) -> Data? {
        return addressRecords[SignalProtocolAddress(address!.pointee)]!
    }

    static func store(record: UnsafeMutablePointer<UInt8>?,
                      size: Int,
                      forAddress address:UnsafePointer<signal_protocol_address>?) -> Int32 {
        let signalProtocolAddress = SignalProtocolAddress(address!.pointee)
        addresses[signalProtocolAddress.name]?.append(signalProtocolAddress)
        return SignalResult.success
    }

    static func load(record: UnsafeMutablePointer<OpaquePointer?>?,
                     forAddress address: UnsafePointer<signal_protocol_address>?) -> Int32 {
        guard let data = fetchRecord(forAddress: address) else {
            return SignalResult.failure
        }
        let bytes = data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return pointer
        }
        let signalBuffer = signal_buffer_create(bytes, data.count)
        record?.pointee = signalBuffer
        return SignalResult.success
    }

    static func contains(address: UnsafePointer<signal_protocol_address>?) -> Int32 {
        if let _ = fetchRecord(forAddress: address) {
            return SignalResult.exists
        }
        return SignalResult.doesNotExist
    }

    static func getSubDeviceSessions(sessions: UnsafeMutablePointer<OpaquePointer?>?,
                                     name: UnsafePointer<Int8>?,
                                     nameLen: Int) -> Int32 {
        let key = SignalProtocolAddress.nameFor(name!, nameLen)
        let signalIntList = signal_int_list_alloc()
        for address in addresses[key]! {
            signal_int_list_push_back(signalIntList, address.address.device_id)
        }
        sessions?.pointee = signalIntList
        return SignalResult.success
    }

    static func delete(address: UnsafePointer<signal_protocol_address>?) -> Int32 {
        let signalProtocolAddress = SignalProtocolAddress(address!.pointee)
        addresses.removeValue(forKey: signalProtocolAddress.name)
        addressRecords.removeValue(forKey: signalProtocolAddress)
        return SignalResult.failure
    }

    static func deleteAll(name: UnsafePointer<Int8>?, nameLen: Int) -> Int32 {
        let key = SignalProtocolAddress.nameFor(name!, nameLen)
        for address in addresses[key]! {
            addressRecords.removeValue(forKey: address)
        }
        addresses.removeValue(forKey: key)
        return SignalResult.success
    }

    static func store(record: UnsafeMutablePointer<UInt8>?,
                      recordLen: Int,
                      forPreKeyId preKeyId:UInt32) -> Int32 {
        preKeyRecords[preKeyId] = recordToData(record, recordLen)
        return SignalResult.success
    }

    static func load(record: UnsafeMutablePointer<OpaquePointer?>?, preKeyId: UInt32) -> Int32 {
        guard let data = preKeyRecords[preKeyId] else {
            return SignalResult.failure
        }
        let bytes = data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return pointer
        }
        let signalBuffer = signal_buffer_create(bytes, data.count)
        record?.pointee = signalBuffer
        return SignalResult.success
    }

    static func contains(preKeyId: UInt32) -> Int32 {
        if let _ = preKeyRecords[preKeyId] {
            return SignalResult.exists
        }
        return SignalResult.doesNotExist
    }

    static func delete(preKeyId: UInt32) -> Int32 {
        if let _ = preKeyRecords[preKeyId] {
            return SignalResult.exists
        }
        return SignalResult.doesNotExist
    }

    static func store(record: UnsafeMutablePointer<UInt8>?,
                      recordLen: Int,
                      forSignedPreKeyId signedPreKeyId:UInt32) -> Int32 {
        signedPreKeyRecords[signedPreKeyId] = recordToData(record, recordLen)
        return SignalResult.success
    }

    static func load(record: UnsafeMutablePointer<OpaquePointer?>?, signedPreKeyId: UInt32) -> Int32 {
        guard let data = signedPreKeyRecords[signedPreKeyId] else {
            return SignalResult.failure
        }
        let bytes = data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UnsafePointer<UInt8> in
            return pointer
        }
        let signalBuffer = signal_buffer_create(bytes, data.count)
        record?.pointee = signalBuffer
        return SignalResult.success
    }

    static func contains(signedPreKeyId: UInt32) -> Int32 {
        if let _ = signedPreKeyRecords[signedPreKeyId] {
            return SignalResult.exists
        }
        return SignalResult.doesNotExist
    }

    static func delete(signedPreKeyId: UInt32) -> Int32 {
        if let _ = signedPreKeyRecords[signedPreKeyId] {
            return SignalResult.exists
        }
        return SignalResult.doesNotExist
    }

    static func save(keyData: UnsafeMutablePointer<UInt8>?,
                     keyLen: Int,
                     forAddress address: UnsafePointer<signal_protocol_address>?) -> Int32 {
        let signalProtocolAddress = SignalProtocolAddress(address!.pointee)
        addressIdentityKeys[signalProtocolAddress] = recordToData(keyData, keyLen)
        return SignalResult.success
    }

    static func isTrusted(keyData: UnsafeMutablePointer<UInt8>?,
                          keyLen: Int,
                          forAddress address: UnsafePointer<signal_protocol_address>?) -> Int32 {
        let signalProtocolAddress = SignalProtocolAddress(address!.pointee)
        let existingKey = addressIdentityKeys[signalProtocolAddress]
        let newKey = recordToData(keyData, keyLen)
        return existingKey == newKey ? SignalResult.success : SignalResult.failure
    }
}
