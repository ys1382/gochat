import Foundation
import RNCryptor

class Crypto {

    private let password: String

    init(password: String) {
        self.password = password
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
}
