import Foundation

final class ThemisTransport: TSSessionTransportInterface {
    private var serverId: String?
    private var serverPublicKeyData: Data?

    func setupKeys(_ serverId: String, serverPublicKey: Data) {
        self.serverId = serverId
        serverPublicKeyData = serverPublicKey
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        if serverId!.data(using: .utf8)! != binaryId {
            print("mismatch")
        }
        print("retrieved public key for \(String(describing: String(data: binaryId!, encoding: String.Encoding.utf8)!))")
        return serverPublicKeyData!
    }
}

class Peer3 {

    enum Status {
        case begun
        case publicKeySent
        case sessionEstablished
    }
    var status: Status = .begun

    var transport = ThemisTransport()
    var session: TSSession?
    var clientIdData: Data
    var peerId: String
    var clientPrivateKey: Data? = nil
    var clientPublicKey: Data? = nil
    var serverPublicKey: Data? = nil

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

    func sendMessage(_ message: Data) {
        Backend.shared.sendEnvelope(message, to: peerId)
    }

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

    func sendEncryptedMessage(_ plainText: String) {
        do {
            let encrypted = try session!.wrap(plainText.data(using: .utf8))
            sendMessage(encrypted)
        } catch {
            print(error.localizedDescription)
        }
    }

    func stringFromData(_ data: Data) -> String {
        return String(data: data, encoding: .utf8)!
    }
}

class ThemisExample {
    static func go() {
//        let alice = Peer3(clientId: "Alice", peerId: "Carol")
//        let _ = Peer3(clientId: "Carol", peerId: "Alice")
//        alice.connect()
    }
}
