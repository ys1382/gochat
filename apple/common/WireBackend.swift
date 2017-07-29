import Foundation

// for use of Wire.proto
class WireBackend {

    static let shared = WireBackend()
    private let network = Network()
    private var sessionId: String?
    private var crypto: Crypto?
    private var queues = [String:[Hold]]()

    func connect() {
        network.connect()
    }

    private func send(_ wireBuilder: Wire.Builder) {
        do {
            var annotated = wireBuilder
            if let sessionId = sessionId {
                annotated = annotated.setSessionId(sessionId)
            }
            network.send(try annotated.build().data())
        } catch {
            print(error.localizedDescription)
        }
    }

    // encryption handshake

    func sendPublicKey(_ localPublicKey: Data, to: String, isResponse: Bool) {
        let which: Wire.Which = isResponse ? .publicKeyResponse : .publicKey
        let wireBuilder = Wire.Builder().setPayload(localPublicKey).setWhich(which).setTo(to)
        send(wireBuilder)
    }

    private func didReceivePublicKey(_ haber: Wire) {
        let isResponse = haber.which == .publicKeyResponse
        crypto!.setPublicKey(
            key: haber.payload,
            peerId:haber.from,
            isResponse: isResponse)
    }
    
    func sendHandshake(message: Data, to peerId: String) {
        let wireBuilder = Wire.Builder().setPayload(message).setWhich(.handshake).setTo(peerId)
        send(wireBuilder)
    }

    func handshook(with peerId: String) {
        if let q = queues[peerId] {
            for hold in q {
                encryptAndSend(data: hold.data, peerId: peerId)
            }
        }
    }

    // queue messages while waiting for handshake to complete

    struct Hold {
        var data: Data
        var peerId: String
    }

    private func enqueue(data: Data, peerId: String) {
        let hold = Hold(data: data, peerId: peerId)
        var q = queues[peerId]
        if q == nil {
            queues[peerId] = [hold]
        } else {
            q!.append(hold)
        }
    }

    // communication with server

    func didReceiveFromServer(_ data: Data) {
        guard let wire = try? Wire.parseFrom(data:data) else {
            print("Could not deserialize wire")
            return
        }
        if let sid = wire.sessionId, sessionId == nil {
            authenticated(sessionId: sid)
        }

        print("read \(data.count) bytes for \(wire.which) from server")
        do {
            switch wire.which {
            case .contacts:             Model.shared.didReceiveContacts(wire.contacts)
            case .presence:             Model.shared.didReceivePresence(wire)
            case .store:                try didReceiveStore(wire)
            case .handshake:            fallthrough
            case .payload:              crypto!.didReceivePayload(wire.payload, from: wire.from)
            case .publicKey:            fallthrough
            case .publicKeyResponse:    didReceivePublicKey(wire)
            default:                    print("did not handle \(wire.which)")
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    // tell the server to store data
    func sendStore(key: String, value: Data) {
        do {
            guard let encrypted = crypto?.keyDerivationEncrypt(data: value) else {
                print("could not encrypt store")
                return
            }
            let store = try Store.Builder().setKey(key.data(using: .utf8)!).build()
            let wireBuilder = Wire.Builder().setStore(store).setWhich(.store).setPayload(encrypted)
            send(wireBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    // request the server to send back stored data
    func sendLoad(key: String) {
        let wireBuilder = Wire.Builder().setWhich(.load).setPayload(key.data(using: .utf8)!)
        send(wireBuilder)
    }

    // the server sent back stored data, due to a .load request
    private func didReceiveStore(_ wire: Wire) throws {
        guard let value = crypto?.keyDerivationDecrypt(ciphertext: wire.payload) else {
            print("could not decrypt store")
            return
        }
        try Model.shared.didReceiveStore(key: wire.store.key, value: value)
    }

    func login(username: String, password: String) {
        let wireBuilder = Wire.Builder().setLogin(username).setWhich(.login)
        send(wireBuilder)
    }

    private func authenticated(sessionId sid: String) {
        sessionId = sid
        Auth.shared.save()
        crypto = Crypto(password: Auth.shared.password!)
        EventBus.post(.authenticated)
    }

    func sendContacts(_ contacts: [Contact]) {
        let wireBuilder = Wire.Builder().setContacts(contacts).setWhich(.contacts)
        send(wireBuilder)
    }

    func send(data: Data, peerId: String) {
        if crypto!.isSessionEstablished(peerId: peerId) {
            encryptAndSend(data: data, peerId: peerId)
        } else {
            enqueue(data: data, peerId: peerId)
        }
    }

    private func encryptAndSend(data: Data, peerId: String) {
        guard let encrypted = crypto?.encrypt(data: data, peerId: peerId) else {
            print("encryption failed")
            return
        }
        let payloadBuilder = Wire.Builder().setPayload(encrypted).setWhich(.payload).setTo(peerId)
        send(payloadBuilder)
    }
}
