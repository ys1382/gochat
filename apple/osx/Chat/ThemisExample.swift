import Foundation

final class ThemisTransport: TSSessionTransportInterface {
    private var serverId: String?
    private var serverPublicKeyData: Data?

    func setupKeys(_ serverId: String, serverPublicKey: Data) {
        self.serverId = serverId
        self.serverPublicKeyData = serverPublicKey
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        if serverId!.data(using: .utf8)! != binaryId {
            print("mismatch")
        }
        return serverPublicKeyData!
    }

}

class Peer {

    private static var peers = [String:Peer]()

    var transport = ThemisTransport()
    var session: TSSession?
    var clientIdData: Data
    var peerId: String
    var clientPrivateKey: Data?
    var clientPublicKey: Data?
    var serverPublicKey: Data? {
        didSet {
            self.transport.setupKeys(peerId, serverPublicKey: serverPublicKey!)
            self.session = TSSession(userId: clientIdData, privateKey: clientPrivateKey, callbacks: self.transport)
        }
    }
    var sessionEstablished = false

    init(clientId: String, peerId: String) {

        self.clientIdData = clientId.data(using: .utf8)!
        self.peerId = peerId

        guard let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC) else {
            print("Error occurred while initialising object keyGeneratorEC", #function)
            return
        }
        self.clientPrivateKey = keyGeneratorEC.privateKey as Data
        self.clientPublicKey = keyGeneratorEC.publicKey as Data

        Peer.peers[clientId] = self
    }

    func connect() {

        Peer.peers[peerId]!.serverPublicKey = clientPublicKey
        self.serverPublicKey = Peer.peers[peerId]!.clientPublicKey

        do {
            guard let message = try session?.connectRequest() else {
                print("could not connectRequest")
                return
            }
            sendMessage(message)
        } catch {
            print(error.localizedDescription)
        }
    }

    func sendMessage(_ message: Data) {
        Peer.peers[peerId]!.didReceive(message)
    }

    func didReceive(_ data: Data) {
        do {
            let decryptedMessage = try self.session!.unwrapData(data)
            if !session!.isSessionEstablished() {
                sendMessage(decryptedMessage)
            } else if !self.sessionEstablished {
                print("session established with " + peerId)
                self.sessionEstablished = true
                sendMessage(decryptedMessage)
                sendEncryptedMessage("hi " + peerId)
            } else {
                print("received message: " + stringFromData(decryptedMessage))
            }
        } catch {
            if let session = self.session, session.isSessionEstablished() == true {
                print("Session established with " + peerId)
                self.sessionEstablished = true
                sendEncryptedMessage("hi " + peerId)
            } else {
                print(error.localizedDescription)
            }
        }
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
        let alice = Peer(clientId: "Alice", peerId: "Carol")
        let _ = Peer(clientId: "Carol", peerId: "Alice")
        alice.connect()
    }
}
