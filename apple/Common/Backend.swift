import Foundation
import Starscream

class Backend: WebSocketDelegate {

    static let address = "ws://107.170.4.248:8000/ws"
//    static let address = "ws://localhost:8000/ws"
//    static let address = "ws://192.168.8.100:8000/ws"

    static let shared = Backend()

    private var audio = NetworkInput()
    private var video = NetworkInput()
    
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

    var videoSessionStart: ((_ sid: String, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ sid: String)->Void)?

    var audioSessionStart: ((_ sid: String, _ format: AudioFormat) throws ->IODataProtocol?)?
    var audioSessionStop: ((_ sid: String)->Void)?
    
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

    private func createAVSession(_ to: String, _ data: NSData?, _ active: Bool) throws -> Haber.Builder {
        let sessionBuilder = Avsession.Builder().setActive(active)
        
        if data != nil {
            sessionBuilder.setData(data! as Data)
        }
        
        return Haber.Builder().setAvSession(try sessionBuilder.build()).setTo(to)
    }
    
    func sendVideoSession(_ to: String, _ data: NSData?, _ active: Bool) {
        do {
            send(try createAVSession(to, data, active).setWhich(.videoSession))
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendAudioSession(_ to: String, _ data: NSData?, _ active: Bool) {
        do {
            send(try createAVSession(to, data, active).setWhich(.audioSession))
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendVideo(_ to: String, _ data: NSData) {
        
        assert_av_capture_queue()
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try VideoSample.Builder().setImage(image).build()
            let av = try Av.Builder().setVideo(media).build()
            
            let haberBuilder = Haber.Builder().setAv(av).setWhich(.av)
            haberBuilder.setTo(to)
            
            Backend.shared.send(haberBuilder)
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendAudio(_ to: String, _ data: NSData) {
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try AudioSample.Builder().setImage(image).build()
            let av = try Av.Builder().setAudio(media).build()
            
            let haberBuilder = Haber.Builder().setAv(av).setWhich(.av)
            haberBuilder.setTo(to)
            
            Backend.shared.send(haberBuilder)
        }
        catch {
            logNetworkError(error)
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Receive
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func getsAV(_ haber: Haber) {
        if (haber.av.hasAudio) {
            audio.process(haber.from, [AACPart.NetworkPacket.rawValue: haber.av.audio.image.data as NSData])
        }
        
        if (haber.av.hasVideo) {
            video.process(haber.from, [H264Part.NetworkPacket.rawValue: haber.av.video.image.data as NSData])
        }
    }

    func getsVideoSession(_ haber: Haber) {
        do {
            if haber.avSession.hasActive && haber.avSession.active {
                let format = try VideoFormat.fromNetwork(haber.avSession.data! as NSData)
                guard let output = try videoSessionStart?(haber.from, format) else { return }

                video.removeAll()
                video.add(haber.from, output)
            }
            else {
                videoSessionStop?(haber.from)
                video.remove(haber.from)
            }
        }
        catch {
            logNetworkError(error)
        }
    }

    func getsAudioSession(_ haber: Haber) {
        do {
            if haber.avSession.hasActive && haber.avSession.active {
                let format = try AudioFormat.fromNetwork(haber.avSession.data! as NSData)
                guard let output = try audioSessionStart?(haber.from, format) else { return }
                
                audio.removeAll()
                audio.add(haber.from, output)
            }
            else {
                audioSessionStop?(haber.from)
                audio.remove(haber.from)
            }
        }
        catch {
            logNetworkError(error)
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
            getsAV(haber)
        case .audioSession:
            getsAudioSession(haber)
        case .videoSession:
            getsVideoSession(haber)
        default:
            logNetworkError("did not handle \(haber.which)")
        }
    }
}
