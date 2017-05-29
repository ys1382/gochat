import Foundation
import Starscream

class Backend: WebSocketDelegate {

    static let address = "ws://107.170.4.248:8000/ws"
//    static let address = "ws://localhost:8000/ws"
//    static let address = "ws://192.168.8.100:8000/ws"

    static let shared = Backend()

    public var audio: DataProtocol?
    public var video: DataProtocol?
    
    private var websocket: WebSocket?
    private var sessionId: String?

    func connect(withUsername: String) {
        guard let url = URL(string: Backend.address) else {
            logNetworkError("could not create url from " + Backend.address)
            return
        }
        self.websocket = WebSocket(url: url)
        Model.shared.username = withUsername
        websocket?.delegate = self
        websocket?.connect()
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Send
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func send(_ haberBuilder:Haber.Builder) {
        guard let haber = try? haberBuilder.setSessionId(self.sessionId ?? "").build() else {
            logNetworkError("could not create haber")
            return
        }
        logNetwork("write \(haber.data().count) bytes for \(haber.which)")
        self.websocket?.write(data: haber.data())
    }

    func sendText(_ body: String, to: String) {
        guard let update = try? Text.Builder().setBody(body).build() else {
            logNetworkError("could not create Text")
            return
        }
        let haberBuilder = Haber.Builder().setText(update).setWhich(.text).setTo(to)
        self.send(haberBuilder)
    }

    func sendContacts(_ contacts: [String:Contact]) {
        let haberBuilder = Haber.Builder().setContacts(Array(contacts.values)).setWhich(.contacts)
        Backend.shared.send(haberBuilder)
    }

    func sendVideo(_ data: NSData) {
        
        guard let username = Model.shared.watching else { return }
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try VideoSample.Builder().setImage(image).build()
            let av = try Av.Builder().setVideo(media).build()
            
            let haberBuilder = Haber.Builder().setAv(av).setWhich(.av)
            haberBuilder.setTo(username)
            
            Backend.shared.send(haberBuilder)
        }
        catch {
            logNetwork(error.localizedDescription)
        }
    }

    func sendAudio(_ data: NSData) {
        
        guard let username = Model.shared.watching else { return }

        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try AudioSample.Builder().setImage(image).build()
            let av = try Av.Builder().setAudio(media).build()
            
            let haberBuilder = Haber.Builder().setAv(av).setWhich(.av)
            haberBuilder.setTo(username)
            
            Backend.shared.send(haberBuilder)
        }
        catch {
            logNetwork(error.localizedDescription)
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Receive
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func getsAV(haber: Haber) {
        if (haber.av.hasAudio) {
            audio?.process([AACPart.NetworkPacket.rawValue: haber.av.audio.image.data as NSData])
        }
        
        if (haber.av.hasVideo) {
            video?.process([H264Part.NetworkPacket.rawValue: haber.av.video.image.data as NSData])
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // websocket delegate
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
        logNetwork("disconnected")
    }

    public func websocketDidReceiveMessage(_ websocket: Starscream.WebSocket, text: String) {
        logNetwork("websocketDidReceiveMessage")
    }

    public func websocketDidReceiveData(_ websocket: Starscream.WebSocket, data: Data) {
        guard let haber = try? Haber.parseFrom(data:data) else {
                logNetworkError("Could not deserialize")
                return
        }

        if haber.hasSessionId {
            self.sessionId = haber.sessionId
        }

        logNetwork("read \(data.count) bytes for \(haber.which)")
        switch haber.which {
        case .contacts:
            Model.shared.didReceiveRoster(haber.contacts)
        case .text:
            Model.shared.didReceiveText(haber)
        case .presence:
            Model.shared.didReceivePresence(haber)
        case .av:
            getsAV(haber: haber)
        default:
            logNetworkError("did not handle \(haber.which)")
        }
    }
}
