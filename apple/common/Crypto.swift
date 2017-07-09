import Foundation

class Crypto {

    private var cellSeal: TSCellSeal? = nil
    private var transport: Transport? = nil
    private var clientPrivateKey: Data? = nil
    private var serverPublicKey: Data? = nil
    private var session: TSSession? = nil
    private let kClientIdString = "kClientIdString"

    init(password: String) {
        guard let key = password.data(using: String.Encoding.utf8) else {
            print("Error occurred while initialising object cellSeal", #function)
            return
        }

        let serverPublicKeyString: String = "VUVDMgAAAC2ELbj5Aue5xjiJWW3P2KNrBX+HkaeJAb+Z4MrK0cWZlAfpBUql"
        let clientPrivateKeyString: String = "UkVDMgAAAC13PCVZAKOczZXUpvkhsC+xvwWnv3CLmlG0Wzy8ZBMnT+2yx/dg"
        self.serverPublicKey = Data(base64Encoded: serverPublicKeyString, options: .ignoreUnknownCharacters)!
        self.clientPrivateKey = Data(base64Encoded: clientPrivateKeyString, options: .ignoreUnknownCharacters)!

        self.transport = Transport(otherPublickKey: serverPublicKey!)
        self.cellSeal = TSCellSeal(key: key)
        self.initialiseSecureSession()
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

    func generateKeys() {
        guard let keyGeneratorEC = TSKeyGen(algorithm: .EC) else {
            print("Error occurred while initialising object keyGeneratorEC", #function)
            return
        }
        self.clientPrivateKey = keyGeneratorEC.privateKey! as Data
//        self.clientPublicKey = keyGeneratorEC.publicKey
    }
    func initialiseSecureSession() {
        let clientId = kClientIdString.data(using: String.Encoding.utf8)
        self.session = TSSession(userId: clientId, privateKey: self.clientPrivateKey!, callbacks: self.transport)

        var error: NSError?
        session?.connect(&error)

//        do {
//            let connectRequest = try session?.connectRequest()
//        } catch let error as NSError {
//            print("Error occurred while connecting to session \(error)", #function)
//        }
    }

    func sendAndReceiveData(message: String) {
        do {
            let encryptedMessage = try self.session?.wrap(message.data(using: String.Encoding.utf8))

        // ...

            let decryptedMessage = try self.session!.unwrapData(encryptedMessage) as NSData
            let decryptedString = String(data: decryptedMessage as Data, encoding: String.Encoding.utf8)
            print("decryptedString: " + decryptedString!)

        } catch let error as NSError {
            print("Error occurred while decrypting message \(error)", #function)
            return
        }
    }
}

class Transport: TSSessionTransportInterface {

    var peerPublicKey: Data
    init(otherPublickKey: Data) {
        self.peerPublicKey = otherPublickKey
    }

    override func send(_ data: Data!, error: NSErrorPointer) {
        print("send")
    }

    override func receiveData() throws -> Data {
        print("recv")
        return Data()
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        let error: NSError = NSError(domain: "com.example", code: -1, userInfo: nil)
        let stringFromData =  String(data: binaryId, encoding: .utf8)
        if stringFromData == nil {
            throw error
        }

        if stringFromData == "peerId" {
            return self.peerPublicKey
        }
        return Data()
    }
}
