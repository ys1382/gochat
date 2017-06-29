import Foundation

class Crypto {

    private let cellSeal: TSCellSeal?
    private static var lock = NSRecursiveLock()

    init(password: String) {
        guard let key = password.data(using: String.Encoding.utf8) else {
            print("Error occurred while initialising object cellSeal", #function)
            self.cellSeal = nil
            return
        }
        self.cellSeal = TSCellSeal(key: key)
    }

    func keyDerivationEncrypt(data: Data) -> Data? {
        do {
            return try cellSeal?.wrap(data, context: nil)
        } catch let error as NSError {
            print("Error occurred while encrypting \(error)", #function)
            return nil
        }
    }

    func keyDerivationDecrypt(ciphertext: Data) -> Data? {
        do {
            return try cellSeal?.unwrapData(ciphertext, context: nil)
        } catch let error as NSError {
            print("Error occurred while decrypting \(error)", #function)
            return nil
        }
    }
}
