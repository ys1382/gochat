import Foundation

class Backend {

    private static let shared = Backend()
    private let network = Network()
    private var sessionId: String?

    private func send(_ haberBuilder:Haber.Builder) {
        guard let haber = try? haberBuilder.setSessionId(self.sessionId ?? "").build() else {
            print("could not create haber")
            return
        }
        print("write \(haber.data().count) bytes for \(haber.which)")
        self.network.send(haber.data())
    }

    static func connect() {
        shared.network.connect()
    }

    static func sendText(_ body: String, to: String) {
        guard let update = try? Text.Builder().setBody(body).build() else {
            print("could not create Text")
            return
        }
        let haberBuilder = Haber.Builder().setText(update).setWhich(.text).setTo(to)
        shared.send(haberBuilder)
    }

    static func sendContacts(_ contacts: [String:Contact]) {
        let haberBuilder = Haber.Builder().setContacts(Array(contacts.values)).setWhich(.contacts)
        shared.send(haberBuilder)
    }

    static func store(key: Data, value: Haber) {
        do {
            let store = try Store.Builder().setKey(key).setValue(value.data()).build()
            let haberBuilder = Haber.Builder().setStore(store).setWhich(.store)
            shared.send(haberBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    static func load(key: Data) {
        let haberBuilder = Haber.Builder().setWhich(.load)
        shared.send(haberBuilder)
    }

    static func register(username: String, password: String) {
        print("register not implemented")
    }

    static func login(username: String, password: String) {
        do {
            let login = try Login.Builder().setUsername(username).build()
            let haberBuilder = Haber.Builder().setLogin(login).setWhich(.login)
            shared.send(haberBuilder)
        } catch {
            print(error.localizedDescription)
        }
    }

    static func didReceiveData(_ data: Data) {
        guard let haber = try? Haber.parseFrom(data:data) else {
                print("Could not deserialize")
                return
        }
    
        print("read \(data.count) bytes for \(haber.which)")
        switch haber.which {
        case .contacts:
            Model.shared.didReceiveRoster(haber.contacts)
        case .text:
            Model.shared.didReceiveText(haber)
        case .presence:
            Model.shared.didReceivePresence(haber)
        case .store:
            Model.shared.didReceiveStore(haber)
        default:
            print("did not handle \(haber.which)")
        }
    }
}
