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

    private func send(_ haberBuilder:Haber.Builder) {
        guard let haber = try? haberBuilder.setSessionId(sessionId ?? "").build() else {
            print("could not create haber")
            return
        }

        if haber.to == nil ||
            haber.which == .publicKey ||
            haber.which == .publicKeyResponse ||
            haber.which == .handshake ||
            crypto!.isSessionEstablishedFor(haber.to) {
            send(haber)
        } else {
            crypto!.establishSession(forPeerId: haber.to)
            enqueue(haber)
        }
    }

    private func enqueue(_ haber: Haber) {
        var q = queues[haber.to]
        if q == nil {
            queues[haber.to] = [haber]
        } else {
            q!.append(haber)
        }
    }

    func handshook(with peerId: String) {
        if let q = queues[peerId] {
            for haber in q {
                send(haber)
            }
        }
    }

    private func send(_ haber: Haber) {
        print("write \(haber.data().count) bytes for \(haber.which) to \(haber.to ?? "server")")
        network.send(haber.data())
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

    func sendEnvelope(_ body: Data, to: String) {
        let haberBuilder = Haber.Builder().setPayload(body).setWhich(.envelope).setTo(to)
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
                case .envelope:             didReceiveEnvelope(haber)
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

    private func didReceiveEnvelope(_ haber: Haber) {
        guard let from = haber.from else {
            print("anonymous envelope")
            return
        }
        crypto!.handle(data: haber.payload, from: from)
    }

    private func authenticated(sessionId sid: String) {
        sessionId = sid

        guard let username = credential?.username, let password = credential?.password else {
            print("authentication without credentials")
            return
        }

        LocalStorage.store(username, forKey: .username)
        LocalStorage.store(password, forKey: .password)
        crypto = Crypto(username: username, password: password)

        EventBus.post(.authenticated)
    }

    // used for debugging, call at start of init()
    private func clearLocalCredentialsAndLoginAgain() {
        LocalStorage.remove(key: .username)
        LocalStorage.remove(key: .password)
    }
}
