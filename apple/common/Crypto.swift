import Foundation

class Crypto {

    private class Peer {
        var id: String
        var session: TSSession
        var remotePublicKey: Data?

        init(peerId: String, localId: String, localPrivateKey: Data, transport: Transport) {
            self.id = peerId
            self.session = TSSession(userId: localId.data(using: .utf8)!, privateKey: localPrivateKey, callbacks: transport)
        }
    }

    private class Transport: TSSessionTransportInterface {
        private var peers = [String:Peer]()

        func get(_ peerId: String) -> Peer? {
            return peers[peerId]
        }

        func contains(peerId: String) -> Bool {
            return peers[peerId] != nil
        }

        func addPeer(_ peer: Peer) {
            peers[peer.id] = peer
        }

        override func publicKey(for peerId: Data!) throws -> Data {
            let key = String(data: peerId, encoding: .utf8)!
            return peers[key]?.remotePublicKey ?? Data()
        }
    }

    private let transport: Transport
    private let cellSeal: TSCellSeal
    private let localId: String
    private let localPublicKey: Data
    private let localPrivateKey: Data

    init(username: String, password: String) {
        localId = username

        let key = password.data(using: .utf8)!
        cellSeal = TSCellSeal(key: key)

        let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC)!
        localPrivateKey = keyGeneratorEC.privateKey as Data
        localPublicKey = keyGeneratorEC.publicKey as Data

        transport = Transport()
    }

    func setPublicKey(key: Data, for remoteId: String) {
        let peer = Peer(peerId: remoteId, localId: localId, localPrivateKey: localPrivateKey, transport: transport)
        transport.addPeer(peer)
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

    func sendPublicKey(to peerId: String) {
        if transport.contains(peerId: peerId) {
            return
        }
        let peer = Peer(peerId: peerId, localId: peerId, localPrivateKey: localPrivateKey, transport: transport)
        transport.addPeer(peer)
        Backend.shared.sendPublicKey(localPublicKey, to: peerId)
    }

    func didReceivePublicKey(_ remotePublicKey: Data, from peerId: String) {
        if let peer = transport.get(peerId) { // then we are the initiator
            do {
                let request = try peer.session.connectRequest()
                Backend.shared.sendData(request, to: peerId)
            } catch {
                print(error.localizedDescription)
            }
        } else { // we are not the initiator
            sendPublicKey(to: peerId)
        }
    }
}
