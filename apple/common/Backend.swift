import Foundation

class Backend {

    static let shared = Backend()
    private let network = Network()
    private var sessionId: String?
    private var crypto: Crypto?
    private var queues = [String:[Wire]]() // peer id : object to send after handshake is complete

    struct Credential {
        let username: String
        let password: String
    }
    var credential: Credential?

    private init() {
        if let username = LocalStorage.loadString(forKey: .username),
            let password = LocalStorage.loadString(forKey: .password) {
            credential = Credential(username: username, password: password)
        }
    }

    private func dontEncrypt(_ wireBuilder: Wire.Builder) -> Bool {
        return
            !wireBuilder.hasTo ||
            wireBuilder.which == .publicKey ||
            wireBuilder.which == .publicKeyResponse ||
            wireBuilder.which == .handshake
    }

    private func send(_ wireBuilder:Wire.Builder) {
        do {
            if dontEncrypt(wireBuilder) {
                try buildAndSend(wireBuilder)
            } else if crypto!.isSessionEstablishedFor(wireBuilder.to) {
                try encryptAndSend(wireBuilder.build())
            } else {
                enqueue(wireBuilder)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    private func enqueue(_ wireBuilder: Wire.Builder) {
        do {
            let wire = try wireBuilder.build()
            var q = queues[wire.to]
            if q == nil {
                queues[wire.to] = [wire]
            } else {
                q!.append(wire)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func handshook(with peerId: String) {
        if let q = queues[peerId] {
            for wire in q {
                encryptAndSend(wire)
            }
        }
    }

    func send(wire: Wire) {
        network.send(wire.data())
    }

    private func buildAndSend(_ wireBuilder: Wire.Builder) throws {
        var annotated = wireBuilder
        if let sessionId = sessionId {
            annotated = annotated.setSessionId(sessionId)
        }
        send(wire: try annotated.build())
    }

    private func encryptAndSend(_ wire: Wire) {
        guard let encrypted = crypto?.encrypt(data: wire.data(), forPeerId: wire.to) else {
            print("encryption failed")
            return
        }
        let payloadBuilder = Wire.Builder().setPayload(encrypted).setWhich(.payload).setTo(wire.to)
        do {
            try buildAndSend(payloadBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    func sendHandshake(message: Data, to peerId: String) {
        let wireBuilder = Wire.Builder().setPayload(message).setWhich(.handshake).setTo(peerId)
        send(wireBuilder)
    }

    func connect() {
        network.connect()
    }

    func sendPublicKey(_ localPublicKey: Data, to: String, isResponse: Bool) {
        let which: Wire.Which = isResponse ? .publicKeyResponse : .publicKey
        let wireBuilder = Wire.Builder().setPayload(localPublicKey).setWhich(which).setTo(to)
        send(wireBuilder)
    }

    func send(_ voipBuilder: Voip.Builder, to: String) {
        do {
            let payload = try voipBuilder.build().data()
            let wireBuilder = Wire.Builder().setPayload(payload).setWhich(.payload).setTo(to)
            send(wireBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    func sendContacts(_ contacts: [Contact]) {
        let wireBuilder = Wire.Builder().setContacts(contacts).setWhich(.contacts)
        send(wireBuilder)
    }

    func sendStore(key: Data, value: Data) {
        do {
            guard let encrypted = crypto?.keyDerivationEncrypt(data: value) else {
                print("could not encrypt store")
                return
            }
            let store = try Store.Builder().setKey(key).build()
            let wireBuilder = Wire.Builder().setStore(store).setWhich(.store).setPayload(encrypted)
            send(wireBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func didReceiveStore(_ wire: Wire) throws {
        guard let value = crypto?.keyDerivationDecrypt(ciphertext: wire.payload) else {
            print("could not decrypt store")
            return
        }
        try Model.shared.didReceiveStore(key: wire.store.key, value: value)
    }

    func sendLoad(key: LocalStorage.Key) {
        sendLoad(key: key.toData())
    }

    func sendLoad(key: Data) {
        let haberBuilder = Wire.Builder().setWhich(.load).setPayload(key)
        send(haberBuilder)
    }

    private func didReceivePublicKey(_ haber: Wire) {
        let isResponse = haber.which == .publicKeyResponse
        crypto!.setPublicKey(
            key: haber.payload,
            peerId:haber.from,
            isResponse: isResponse)
    }

    func login(username: String, password: String) {
        credential = Credential(username: username, password: password)
        let haberBuilder = Wire.Builder().setLogin(username).setWhich(.login)
        send(haberBuilder)
    }

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

    private func authenticated(sessionId sid: String) {
        sessionId = sid

        guard let username = credential?.username, let password = credential?.password else {
            print("authentication without credentials")
            return
        }

        LocalStorage.store(username, forKey: .username)
        LocalStorage.store(password, forKey: .password)
        crypto = Crypto(password: password)

        EventBus.post(.authenticated)
    }

    // clear cached credentials. Used for debugging, call at start of init()
    private func clearLocalCredentialsAndLoginAgain() {
        LocalStorage.remove(key: .username)
        LocalStorage.remove(key: .password)
    }

    // to/from peer, via server

    func sendText(_ body: String, to: String) {
        let voipBuilder = Voip.Builder().setWhich(.text).setPayload(body.data(using: .utf8)!)
        send(voipBuilder, to: to)
    }

    func didReceiveFromPeer(_ data: Data, from peerId: String) {
        guard let voip = try? Voip.parseFrom(data:data) else {
            print("Could not deserialize voip")
            return
        }

        print("read \(data.count) bytes for \(voip.which) from \(peerId)")
        switch voip.which {
            case        .text: Model.shared.didReceiveText(voip.payload, from: peerId)
            default:    print("did not handle \(voip.which)")
        }
    }
}
