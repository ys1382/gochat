import Foundation
import RNCryptor
import SignalProtocolC

class Crypto {

    private let password: String
    private static var lock = NSRecursiveLock()

    init(password: String) {
        self.password = password
        setupSignal()
    }

    func encrypt(data: Data) -> Data {
        return RNCryptor.encrypt(data: data, withPassword: password)
    }

    func decrypt(ciphertext: Data) -> Data? {
        do {
            return try RNCryptor.decrypt(data: ciphertext, withPassword: password)
        } catch {
            print(error)
            return nil
        }
    }

    func setupSignal() {
        var globalContext: OpaquePointer?
        var result: Int32

        result = signal_context_create(&globalContext, &Crypto.lock)
        checkForError(result: result, name: "signal_context_create")

        var provider = signal_crypto_provider()
        result = signal_context_set_crypto_provider(globalContext, &provider)
        checkForError(result: result, name: "signal_context_set_crypto_provider")

        result = signal_context_set_locking_functions(globalContext,
                                                { _ in Crypto.lock.lock() },
                                                { _ in Crypto.lock.unlock() })
        checkForError(result: result, name: "signal_context_set_locking_functions")
    }

    func checkForError(result: Int32, name: String) {
        if result != 0 {
            print("error for \(name): \(result)")
        }
    }
}
