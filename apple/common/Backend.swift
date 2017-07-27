import Foundation

class Backend {

    static let shared = Backend()
    private let network = Network()
    private var sessionId: String?
    private var crypto: Crypto?
    private var queues = [String:[Haber]]() // peer id : object to send after handshake is complete

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

    private func dontEncrypt(_ haberBuilder: Haber.Builder) -> Bool {
        return
            !haberBuilder.hasTo ||
            haberBuilder.which == .publicKey ||
            haberBuilder.which == .publicKeyResponse ||
            haberBuilder.which == .handshake
    }

    private func send(_ haberBuilder:Haber.Builder) {
        do {
            if dontEncrypt(haberBuilder) {
                try buildAndSend(haberBuilder)
            } else if crypto!.isSessionEstablishedFor(haberBuilder.to) {
                try sendEncrypted(haberBuilder)
            } else {
                enqueue(haberBuilder)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    private func enqueue(_ haberBuilder: Haber.Builder) {
        do {
            let haber = try haberBuilder.build()
            var q = queues[haber.to]
            if q == nil {
                queues[haber.to] = [haber]
            } else {
                q!.append(haber)
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func handshook(with peerId: String) {
        if let q = queues[peerId] {
            for haber in q {
                send(haber: haber)
            }
        }
    }

    func send(haber: Haber) {
        network.send(haber.data())
    }

    private func buildAndSend(_ haberBuilder: Haber.Builder) throws {
        let haber = try haberBuilder.setSessionId(sessionId!).setTo(haberBuilder.to).build()
        print("write unencrypted \(haber.data().count) bytes for \(haber.which) to \(haber.to ?? "server")")
        send(haber: haber)
    }

    private func sendEncrypted(_ haberBuilder: Haber.Builder) throws {
        guard let encrypted = try crypto?.encrypt(data: haberBuilder.build().data(), forPeerId: haberBuilder.to) else {
            print("encryption failed")
            return
        }
        let payloadBuilder = Haber.Builder().setPayload(encrypted).setWhich(.payload).setTo(haberBuilder.to)
        try buildAndSend(payloadBuilder)
    }

    func sendHandshake(message: Data, to peerId: String) {
        let haberBuilder = Haber.Builder().setPayload(message).setWhich(.handshake).setTo(peerId)
        send(haberBuilder)
    }

    func connect() {
        network.connect()
    }

    func sendPublicKey(_ localPublicKey: Data, to: String, isResponse: Bool) {
        let which: Haber.Which = isResponse ? .publicKeyResponse : .publicKey
        let haberBuilder = Haber.Builder().setPayload(localPublicKey).setWhich(which).setTo(to)
        send(haberBuilder)
    }

    func sendText(_ body: String, to: String) {
        let haberBuilder = Haber.Builder().setPayload(body.data(using: .utf8)!).setWhich(.text).setTo(to)
        send(haberBuilder)
    }

    func sendContacts(_ contacts: [Contact]) {
        let haberBuilder = Haber.Builder().setContacts(contacts).setWhich(.contacts)
        send(haberBuilder)
    }

    func sendStore(key: Data, value: Data) {
        do {
            guard let encrypted = crypto?.keyDerivationEncrypt(data: value) else {
                print("could not encrypt store")
                return
            }
            let store = try Store.Builder().setKey(key).setValue(encrypted).build()
            let haberBuilder = Haber.Builder().setStore(store).setWhich(.store)
            send(haberBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func didReceiveStore(_ haber: Haber) throws {
        guard let value = crypto?.keyDerivationDecrypt(ciphertext: haber.store.value) else {
            print("could not decrypt store")
            return
        }
        try Model.shared.didReceiveStore(key: haber.store.key, value: value)
    }

    func sendLoad(key: LocalStorage.Key) {
        sendLoad(key: key.toData())
    }

    func sendLoad(key: Data) {
        let haberBuilder = Haber.Builder().setWhich(.load).setPayload(key)
        send(haberBuilder)
    }

    private func didReceivePublicKey(_ haber: Haber) {
        let isResponse = haber.which == .publicKeyResponse
        crypto!.setPublicKey(
            key: haber.payload,
            peerId:haber.from,
            isResponse: isResponse)
    }

    func login(username: String, password: String) {
        credential = Credential(username: username, password: password)
        let haberBuilder = Haber.Builder().setLogin(username).setWhich(.login)
        send(haberBuilder)
    }

    func didReceiveData(_ data: Data) {
        guard let haber = try? Haber.parseFrom(data:data) else {
                print("Could not deserialize")
                return
        }
        if let sid = haber.sessionId, sessionId == nil {
            authenticated(sessionId: sid)
        }
    
        print("read \(data.count) bytes for \(haber.which) from \(haber.from ?? "server")")
        do {
            switch haber.which {
                case .contacts:             Model.shared.didReceiveContacts(haber.contacts)
                case .text:                 Model.shared.didReceiveText(haber, data: data)
                case .presence:             Model.shared.didReceivePresence(haber)
                case .store:                try didReceiveStore(haber)
                case .handshake:            fallthrough
                case .payload:              crypto!.didReceivePayload(haber.payload, from: haber.from)
                case .publicKey:            fallthrough
                case .publicKeyResponse:    didReceivePublicKey(haber)
                default:                    print("did not handle \(haber.which)")
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
}
