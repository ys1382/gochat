import Foundation

class Crypto {

    private let cellSeal: TSCellSeal
    private let localId: String
    private let localPublicKey: Data
    private let localPrivateKey: Data
    private var peers = [String:Peer3]()

    init(username: String, password: String) {
        localId = username

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

    func establishSession(forPeerId peerId: String) {
        let peer = self.peer(forPeerId: peerId)
        if peer.clientPublicKey == nil {
            peer.sendPublicKey(isResponse: false)
        }
    }

    func isSessionEstablishedFor(_ peerId: String) -> Bool {
        let peer = self.peer(forPeerId: peerId)
        if peer.status == .begun {
            peer.sendPublicKey(isResponse: false)
        }
        return peer.status == .sessionEstablished
    }

    private func peer(forPeerId peerId: String) -> Peer3 {
        if peers[peerId] == nil {
            let peer = Peer3(peerId: peerId)
            peers[peerId] = peer
        }
        return peers[peerId]!
    }

    func handle(data: Data, from peerId: String) {
        let peer = self.peer(forPeerId: peerId)
        peer.didReceive(data)
    }

    func setPublicKey(key: Data, peerId: String, isResponse: Bool) {
        let peer = self.peer(forPeerId: peerId)
        peer.setServerPublicKey(key: key, isResponse: isResponse)
    }

    func didReceivePayload(_ payload: Data, from peerId: String) {
        peer(forPeerId: peerId).didReceive(payload)
    }
}
