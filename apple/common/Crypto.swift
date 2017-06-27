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

    func keyDerivationEncrypt(data: Data) -> Data {
        return RNCryptor.encrypt(data: data, withPassword: password)
    }

    func keyDerivationDecrypt(ciphertext: Data) -> Data? {
        do {
            return try RNCryptor.decrypt(data: ciphertext, withPassword: password)
        } catch {
            print(error)
            return nil
        }
    }

    func setupSignal() {
        let globalContext = signalLibraryInitialization()
        signalClientInstallTime(globalContext: globalContext)
        signalBuildSession(globalContext: globalContext)
    }

//    let load2: @convention(c) (UnsafeMutablePointer<OpaquePointer?>?,
//               UnsafePointer<signal_protocol_address>?,
//               UnsafeMutableRawPointer?) -> Int32 = { a,b,c in
//        return 0
//    }
//    var x = signal_protocol_session_store(load_session_func: load2,
//                                          get_sub_device_sessions_func: LocalStorage.getSubDeviceSessions,
//                                          store_session_func: LocalStorage.store1,
//                                          contains_session_func: LocalStorage.contains1,
//                                          delete_session_func: LocalStorage.delete1,
//                                          delete_all_sessions_func: LocalStorage.deleteAll,
//                                          destroy_func: nil,
//                                          user_data: nil)

    func signalBuildSession(globalContext: OpaquePointer?) {
        var storeContext: OpaquePointer?
        signal_protocol_store_context_create(&storeContext, globalContext)
        var sessionStore = signal_protocol_session_store()

        sessionStore.store_session_func = { address, record, recordLen, userData in
            return LocalStorage.store(record: record, size: recordLen, forAddress: address)
        }
        sessionStore.load_session_func = { record, address, userData in
            return LocalStorage.load(record: record, forAddress: address)
        }
        sessionStore.get_sub_device_sessions_func = { sessions, name, nameLen, userData in
            return LocalStorage.getSubDeviceSessions(sessions: sessions, name: name, nameLen: nameLen)
        }
        sessionStore.contains_session_func = { address, userData in
            return LocalStorage.contains(address: address)
        }
        sessionStore.delete_session_func = { address, userData in
            return LocalStorage.delete(address: address)
        }
        sessionStore.delete_all_sessions_func = { name, nameLen, userData in
            return LocalStorage.deleteAll(name: name, nameLen: nameLen)
        }

        sessionStore.destroy_func = { userData in }
        sessionStore.user_data = nil
        signal_protocol_store_context_set_session_store(storeContext, &sessionStore)

        var preKeyStore = signal_protocol_pre_key_store()
        preKeyStore.store_pre_key = { preKeyId, record, recordLen, userData in
            return LocalStorage.store(record: record, recordLen: recordLen, forPreKeyId: preKeyId)
        }
        preKeyStore.load_pre_key = { record, preKeyId, userData in
            return LocalStorage.load(record: record, preKeyId: preKeyId)
        }
        preKeyStore.contains_pre_key = { preKeyId, userData in
            return LocalStorage.contains(preKeyId: preKeyId)
        }
        preKeyStore.remove_pre_key = { preKeyId, userData in
            return LocalStorage.delete(preKeyId: preKeyId)
        }
        preKeyStore.destroy_func = { userData in }
        preKeyStore.user_data = nil
        signal_protocol_store_context_set_pre_key_store(storeContext, &preKeyStore);

        var signedPreKeyStore = signal_protocol_signed_pre_key_store()
        signedPreKeyStore.store_signed_pre_key = { signedPreKeyId, record, recordLen, userData in
            return LocalStorage.store(record: record, recordLen: recordLen, forSignedPreKeyId: signedPreKeyId)
        }
        signedPreKeyStore.load_signed_pre_key = { record, signedPreKeyId, userData in
            return LocalStorage.load(record: record, signedPreKeyId: signedPreKeyId)
        }
        signedPreKeyStore.contains_signed_pre_key = { signedPreKeyId, userData in
            return LocalStorage.contains(signedPreKeyId: signedPreKeyId)
        }
        signedPreKeyStore.remove_signed_pre_key = { signedPreKeyId, userData in
            return LocalStorage.delete(signedPreKeyId: signedPreKeyId)
        }
        signedPreKeyStore.destroy_func = { userData in }
        signedPreKeyStore.user_data = nil
        signal_protocol_store_context_set_signed_pre_key_store(storeContext, &signedPreKeyStore);

        var identityKeyStore = signal_protocol_identity_key_store()
        identityKeyStore.save_identity = { address, keyData, keyLen, userData in
            return LocalStorage.save(keyData: keyData, keyLen: keyLen, forAddress: address)
        }
        identityKeyStore.is_trusted_identity = { address, keyData, keyLen, userData in
            return LocalStorage.isTrusted(keyData: keyData, keyLen: keyLen, forAddress: address)
        }
        identityKeyStore.destroy_func = { userData in }
        identityKeyStore.user_data = nil
        signal_protocol_store_context_set_identity_key_store(storeContext, &identityKeyStore);



        var address = signal_protocol_address(name: "alice", name_len: 5, device_id: 1)
        var builder: OpaquePointer?
        session_builder_create(&builder, storeContext, &address, globalContext);

//        session_builder_process_pre_key_bundle(builder, retrievedPreKey);

        var cipher: OpaquePointer?
        session_cipher_create(&cipher, storeContext, &address, globalContext);

//        var messageLen = 99
//        session_cipher_encrypt(cipher, message, messageLen, &encryptedMessage);
//        let serialized = ciphertext_message_get_serialized(encryptedMessage);
    }

    func signalClientInstallTime(globalContext: OpaquePointer?) {

        if LocalStorage.loadBoolean(forKey: .signalClientInstallTime) {
            return
        }
        LocalStorage.store(true, forKey: .signalClientInstallTime)

        var result: Int32
        var identityKeyPair: OpaquePointer?
        var registrationId: UInt32 = 0
        let extendedRange: Int32 = 0
        let startId: UInt32 = 0
        let count: UInt32 = 100
        var preKeysHead: OpaquePointer?
        var signedPreKey: OpaquePointer?
        let signedPreKeyId: UInt32 = 5
        let timestamp: UInt64 = 0

        result = signal_protocol_key_helper_generate_identity_key_pair(&identityKeyPair, globalContext)
        checkForError(result: result, name: "signal_protocol_key_helper_generate_identity_key_pair")
        result = signal_protocol_key_helper_generate_registration_id(&registrationId, extendedRange, globalContext)
        checkForError(result: result, name: "signal_protocol_key_helper_generate_registration_id")
        result = signal_protocol_key_helper_generate_pre_keys(&preKeysHead, startId, count, globalContext)
        checkForError(result: result, name: "signal_cosignal_protocol_key_helper_generate_pre_keysntext_create")
        result = signal_protocol_key_helper_generate_signed_pre_key(&signedPreKey,
                                                                    identityKeyPair,
                                                                    signedPreKeyId,
                                                                    timestamp,
                                                                    globalContext)
        checkForError(result: result, name: "signal_protocol_key_helper_generate_signed_pre_key")
    }

    func signalLibraryInitialization() -> OpaquePointer? {

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

        return globalContext
    }

    func checkForError(result: Int32, name: String) {
        if result != 0 {
            print("error for \(name): \(result)")
        }
    }
}
