import Foundation
import Starscream

class Backend: WebSocketDelegate {

    static var address = "107.170.4.248"
    static let shared = Backend()

    private var audio = NetworkInput()
    private var video = NetworkInput()
    
    private var websocket: WebSocket?
    private var sessionId: String?

    func connect(withUsername: String) {
        guard let url = URL(string: "ws://\(Backend.address):8000/ws") else {
            logNetworkError("could not create url from " + Backend.address)
            return
        }
        self.websocket = WebSocket(url: url)
        Model.shared.username = withUsername
        websocket?.delegate = self
        websocket?.callbackQueue = DispatchQueue(label: "chat.Websocket")
        websocket?.connect()
    }

    var videoSessionStart: ((_ id: IOID, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ id: IOID)->Void)?

    var audioSessionStart: ((_ id: IOID, _ format: AudioFormat) throws ->IODataProtocol?)?
    var audioSessionStop: ((_ id: IOID)->Void)?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Send
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func send(_ haberBuilder:Haber.Builder, _ details: String) {
        guard let haber = try? haberBuilder.setSessionId(self.sessionId ?? "").build() else {
            logNetworkError("could not create haber")
            return
        }
        logNetwork("write \(haber.data().count) bytes for \(haber.which) \(details)")
        self.websocket?.write(data: haber.data())
    }

    func send(_ haberBuilder:Haber.Builder) {
        send(haberBuilder, "")
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

    private func createAVSession(_ id: IOID, _ data: NSData?, _ active: Bool) throws -> Haber.Builder {
        let sessionBuilder = Avsession.Builder()
            .setSid(id.sid)
            .setGid(id.gid)
            .setActive(active)
        
        if data != nil {
            sessionBuilder.setData(data! as Data)
        }
        
        return Haber.Builder().setAvSession(try sessionBuilder.build()).setTo(id.to)
    }
    
    func sendVideoSession(_ id: IOID, _ data: NSData?, _ active: Bool) {
        do {
            send(try createAVSession(id, data, active).setWhich(.videoSession))
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendAudioSession(_ id: IOID,_ data: NSData?, _ active: Bool) {
        do {
            send(try createAVSession(id, data, active).setWhich(.audioSession))
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendVideo(_ id: IOID, _ data: NSData) {
        
        assert_video_capture_queue()
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try VideoSample.Builder().setImage(image).build()
            let av = try Av.Builder().setVideo(media).build()
            
            let haberBuilder = Haber.Builder()
                .setTo(id.to)
                .setWhich(.av)
                .setAv(av)
                .setAvSession(try Avsession.Builder().setSid(id.sid).build())
            
            Backend.shared.send(haberBuilder, "video")
        }
        catch {
            logNetworkError(error)
        }
    }

    func sendAudio(_ id: IOID, _ data: NSData) {
        
        assert_audio_capture_queue()
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try AudioSample.Builder().setImage(image).build()
            let av = try Av.Builder().setAudio(media).build()
            
            let haberBuilder = Haber.Builder()
                .setTo(id.to)
                .setWhich(.av)
                .setAv(av)
                .setAvSession(try Avsession.Builder().setSid(id.sid).build())

            Backend.shared.send(haberBuilder, "audio")
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
            audio.process(haber.avSession.sid, [AACPart.NetworkPacket.rawValue: haber.av.audio.image.data as NSData])
        }
        
        if (haber.av.hasVideo) {
            video.process(haber.avSession.sid, [H264Part.NetworkPacket.rawValue: haber.av.video.image.data as NSData])
        }
    }

    func getsVideoSession(_ haber: Haber) {
        do {
            if haber.avSession.hasActive && haber.avSession.active {
                video.removeAll()

                let format = try VideoFormat.fromNetwork(haber.avSession.data! as NSData)
                
                try dispatch_sync_on_main {
                    guard let output = try videoSessionStart?(haber.avid, format) else { return }
                    video.add(haber.avSession.sid, output)
                }
            }
            else {
                videoSessionStop?(haber.avid)
                video.remove(haber.avSession.sid)
            }
        }
        catch {
            logNetworkError(error)
        }
    }

    func getsAudioSession(_ haber: Haber) {
        do {
            if haber.avSession.hasActive && haber.avSession.active {
                audio.removeAll()

                let format = try AudioFormat.fromNetwork(haber.avSession.data! as NSData)
                
                try dispatch_sync_on_main {
                    guard let output = try audioSessionStart?(haber.avid, format) else { return }
                    audio.add(haber.avSession.sid, output)
                }
            }
            else {
                audioSessionStop?(haber.avid)
                audio.remove(haber.avSession.sid)
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
            dispatch_sync_on_main { Model.shared.didReceiveRoster(haber.contacts) }
        case .text:
            dispatch_sync_on_main { Model.shared.didReceiveText(haber) }
        case .presence:
            dispatch_sync_on_main { Model.shared.didReceivePresence(haber) }
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

extension Haber {
    var avid: IOID {
        get {
            return IOID(from, to, avSession.sid, avSession.gid)
        }
    }
}
