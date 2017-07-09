import Foundation

class Crypto {

    private class Peer {
        var id: Data
        var session: TSSession
        var remotePublicKey: Data?

        init(peerId: Data, localId: Data, localPrivateKey: Data, transport: Transport) {
            self.id = peerId
            self.session = TSSession(userId: localId, privateKey: localPrivateKey, callbacks: transport)
        }

        init(peerId: String, localId: String, localPrivateKey: Data, transport: Transport) {
            self.id = peerId.data(using: .utf8)!
            self.session = TSSession(userId: localId.data(using: .utf8), privateKey: localPrivateKey, callbacks: transport)
        }
    }

    private class Transport: TSSessionTransportInterface {
        private var peers = [Data:Peer]()

        func contains(peerId: String) -> Bool {
            if let peerIdData = peerId.data(using: .utf8), contains(peerIdData: peerIdData) {
                return true
            }
            return false
        }

        func contains(peerIdData: Data) -> Bool {
            return peers[peerIdData] != nil
        }

        func getPeerFor(_ peerId: String) -> Peer? {
            if let peerIdData = peerId.data(using: .utf8) {
                return peers[peerIdData]
            }
            return nil
        }

        func addPeer(_ peer: Peer) {
            peers[peer.id] = peer
        }

        override func publicKey(for binaryId: Data!) throws -> Data {
            return peers[binaryId]?.remotePublicKey ?? Data()
        }
    }

    private let transport: Transport
    private let cellSeal: TSCellSeal
    private let localId: Data
    private let localPublicKey: Data
    private let localPrivateKey: Data

    init(username: String, password: String) {
        localId = username.data(using: .utf8)!

        let key = password.data(using: .utf8)!
        cellSeal = TSCellSeal(key: key)

        let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC)!
        localPrivateKey = keyGeneratorEC.privateKey as Data
        localPublicKey = keyGeneratorEC.publicKey as Data

        transport = Transport()
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
        if let peer = transport.getPeerFor(peerId) { // then we are the initiator
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
