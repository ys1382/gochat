import Foundation

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
}
