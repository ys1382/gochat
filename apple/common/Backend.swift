import Foundation
import Starscream

class Backend: WebSocketDelegate {

//    static let address = "ws://107.170.4.248:8000/ws"
    static let address = "ws://10.0.0.33:8000/ws"

    static let shared = Backend()

    private var websocket: WebSocket?
    private var sessionId: String?

    func connect(withUsername: String) {
        guard let url = URL(string: Backend.address) else {
            print("could not create url from " + Backend.address)
            return
        }
        self.websocket = WebSocket(url: url)
        Model.shared.username = withUsername
        websocket?.delegate = self
        websocket?.connect()
    }

    func send(_ haberBuilder:Haber.Builder) {
        guard let haber = try? haberBuilder.setSessionId(self.sessionId ?? "").build() else {
            print("could not create haber")
            return
        }
        print("write \(haber.data().count) bytes for \(haber.which)")
        self.websocket?.write(data: haber.data())
    }

    func sendText(_ body: String, to: String) {
        guard let update = try? Text.Builder().setBody(body).build() else {
            print("could not create Text")
            return
        }
        let haberBuilder = Haber.Builder().setText(update).setWhich(.text).setTo(to)
        self.send(haberBuilder)
    }

    func sendContacts(_ contacts: [String:Contact]) {
        let haberBuilder = Haber.Builder().setContacts(Array(contacts.values)).setWhich(.contacts)
        Backend.shared.send(haberBuilder)
    }

    // websocket delegate

    public func websocketDidConnect(_ websocket: Starscream.WebSocket) {
        if let username = Model.shared.username {
            do {
                let login = try Login.Builder().setUsername(username).build()
                let haberBuilder = Haber.Builder().setLogin(login).setWhich(.login)
                self.send(haberBuilder)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    public func websocketDidDisconnect(_ websocket: Starscream.WebSocket, error: NSError?) {
        print("disconnected")
    }

    public func websocketDidReceiveMessage(_ websocket: Starscream.WebSocket, text: String) {
        print("websocketDidReceiveMessage")
    }

    public func websocketDidReceiveData(_ websocket: Starscream.WebSocket, data: Data) {
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
        default:
            print("did not handle \(haber.which)")
        }
    }
}
