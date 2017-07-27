import Foundation

class Crypto {

    private let cellSeal: TSCellSeal
    private let localPublicKey: Data
    private let localPrivateKey: Data
    private var peers = [String:Peer]()

    init(password: String) {
        let key = password.data(using: .utf8)!
        cellSeal = TSCellSeal(key: key)

        let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC)!
        localPrivateKey = keyGeneratorEC.privateKey as Data
        localPublicKey = keyGeneratorEC.publicKey as Data
    }

    func keyDerivationEncrypt(data: Data) -> Data? {
        do {
            return try cellSeal.wrap(data, context: nil)
        } catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }

    func keyDerivationDecrypt(ciphertext: Data) -> Data? {
        do {
            return try cellSeal.unwrapData(ciphertext, context: nil)
        } catch let error as NSError {
            print("Error occurred while decrypting \(error)", #function)
            return nil
        }
    }

//    func establishSession(forPeerId peerId: String) {
//        let peer = self.peer(forPeerId: peerId)
//        if peer.clientPublicKey == nil {
//            peer.sendPublicKey(isResponse: false)
//        }
//    }
//
    func isSessionEstablishedFor(_ peerId: String) -> Bool {
        let peer = self.peer(forPeerId: peerId)
        if peer.status == .begun {
            peer.sendPublicKey(isResponse: false)
        }
        return peer.status == .sessionEstablished
    }

    private func peer(forPeerId peerId: String) -> Peer {
        if peers[peerId] == nil {
            let peer = Peer(peerId: peerId)
            peers[peerId] = peer
        }
        return peers[peerId]!
    }

    func setPublicKey(key: Data, peerId: String, isResponse: Bool) {
        let peer = self.peer(forPeerId: peerId)
        peer.setServerPublicKey(key: key, isResponse: isResponse)
    }

    func didReceivePayload(_ payload: Data, from peerId: String) {
        peer(forPeerId: peerId).didReceive(payload)
    }

    func encrypt(data: Data, forPeerId peerId: String) -> Data? {
        let peer = self.peer(forPeerId: peerId)
        return peer.encrypt(data)
    }
}

private class Transport: TSSessionTransportInterface {
    private var serverId: String?
    private var serverPublicKeyData: Data?

    func setupKeys(_ serverId: String, serverPublicKey: Data) {
        self.serverId = serverId
        serverPublicKeyData = serverPublicKey
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        if serverId!.data(using: .utf16)! != binaryId {
            print("mismatch")
        } else {
            print("retrieved public key for \(String(describing: String(data: binaryId!, encoding: String.Encoding.utf16)!))")
        }
        return serverPublicKeyData!
    }
}

private class Peer {

    enum Status {
        case begun
        case publicKeySent
        case sessionEstablished
    }
    var status: Status = .begun

    var transport = Transport()
    var session: TSSession?
    var clientIdData: Data
    var peerId: String
    var clientPrivateKey: Data? = nil
    var clientPublicKey: Data? = nil

    init(peerId: String) {
        clientIdData = Backend.shared.credential!.username.data(using: .utf8)!
        self.peerId = peerId

        guard let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC) else {
            print("Error occurred while initialising object keyGeneratorEC", #function)
            return
        }
        clientPrivateKey = keyGeneratorEC.privateKey as Data
        clientPublicKey = keyGeneratorEC.publicKey as Data
    }

    func setServerPublicKey(key: Data, isResponse: Bool) {
        transport.setupKeys(peerId, serverPublicKey: key)
        session = TSSession(userId: clientIdData, privateKey: clientPrivateKey, callbacks: transport)
        if isResponse {
            connect()
        } else {
            sendPublicKey(isResponse: true)
        }
    }

    func sendPublicKey(isResponse: Bool) {
        status = .publicKeySent
        Backend.shared.sendPublicKey(clientPublicKey!, to: peerId, isResponse: isResponse)
    }

    func connect() {
        do {
            guard let message = try session?.connectRequest() else {
                print("could not connectRequest")
                return
            }
            Backend.shared.sendHandshake(message: message, to: peerId)
        } catch {
            print(error.localizedDescription)
        }
    }

//    func sendMessage(_ message: Data) {
//        Backend.shared.sendPayload(message, to: peerId)
//    }

    func didReceive(_ data: Data) {
        print("status is \(status)")
        do {
            let decryptedMessage = try session!.unwrapData(data)
            if !session!.isSessionEstablished() { // themis says: send this back
                print("themis says: send this back")
                Backend.shared.sendHandshake(message: decryptedMessage, to: peerId)
            } else if status != .sessionEstablished { // themis says: session now established
                print("themis says: session now established")
                didEstablishSession(sendThisToo: decryptedMessage)
            } else { // themis says: here is the decrypted message
                print("themis says: here is the decrypted message")
                Backend.shared.didReceiveData(decryptedMessage)
            }
        } catch {
            if let session = session, session.isSessionEstablished() {
                print("themis says: session now established 2")
                didEstablishSession() // themis says: session now established (it can happen this way too)
            } else {
                print(error.localizedDescription)
            }
        }
    }

    private func didEstablishSession(sendThisToo: Data? = nil) {
        status = .sessionEstablished
        if let message = sendThisToo {
            Backend.shared.sendHandshake(message: message, to: peerId)
        }
        Backend.shared.handshook(with: peerId)
    }

    func encrypt(_ data: Data) -> Data? {
        do {
            guard let wrappedMessage: Data = try self.session?.wrap(data) else {
                print("Error occurred during wrapping message ", #function)
                return nil
            }
            return wrappedMessage
        } catch let error as NSError {
            print("Error occurred while wrapping message \(error)", #function)
            return nil
        }
    }
}
