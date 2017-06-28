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

    var videoSessionStart: ((NetworkVideoSessionInfo) throws ->IODataProtocol?)?
    var videoSessionStop: ((IOID)->Void)?

    var audioSessionStart: ((NetworkAudioSessionInfo) throws ->IODataProtocol?)?
    var audioSessionStop: ((IOID)->Void)?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Send
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func send(_ haberBuilder:Haber.Builder, _ details: String) {
        guard let haber = try? haberBuilder.setSessionId(self.sessionId ?? "").build() else {
            logNetworkError("could not create haber")
            return
        }
        
        switch haber.which {
        case .av:
            logNetwork("write \(haber.data().count) bytes for \(haber.which) \(details)")
        default:
            logNetworkPrior("write \(haber.data().count) bytes for \(haber.which) \(details)")
        }
        
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

    func sendCallProposal(_ to: String, _ info: NetworkCallProposalInfo) {
        send(try! Haber.Create(.callProposal, to, info))
    }

    func sendCallCancel(_ to: String, _ info: NetworkCallProposalInfo) {
        send(try! Haber.Create(.callCancel, to, info))
    }

    func sendCallAccept(_ to: String, _ info: NetworkCallProposalInfo) {
        send(try! Haber.Create(.callAccept, to, info))
    }

    func sendCallDecline(_ to: String, _ info: NetworkCallProposalInfo) {
        send(try! Haber.Create(.callDecline, to, info))
    }

    func sendOutgoingCallStart(_ to: String, _ info: NetworkCallInfo) {
        send(try! Haber.Create(.callStartOutgoing, to, info))
    }

    func sendIncomingCallStart(_ to: String, _ info: NetworkCallInfo) {
        send(try! Haber.Create(.callStartIncoming, to, info))
    }

    func sendCallStop(_ to: String, _ info: NetworkCallInfo) {
        send(try! Haber.Create(.callStop, to, info))
    }
    
    func sendVideoSession(_ session: NetworkVideoSessionInfo, _ active: Bool) {
        send(try! Haber.Create(.videoSession, session, active).setWhich(.videoSession))
    }

    func sendAudioSession(_ session: NetworkAudioSessionInfo, _ active: Bool) {
        send(try! Haber.Create(.audioSession, session, active).setWhich(.audioSession))
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
                .setVideoSession(try Avsession.Builder().setSid(id.sid).build())
            
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
                .setAudioSession(try Avsession.Builder().setSid(id.sid).build())

            Backend.shared.send(haberBuilder, "audio")
        }
        catch {
            logNetworkError(error)
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Receive
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func getsCallProposal(_ haber: Haber) {
        NetworkCallProposalController.incoming?.start(haber.callProposalInfo)
    }
    
    func getsCallCancel(_ haber: Haber) {
        NetworkCallProposalController.incoming?.stop(haber.callProposalInfo)
        NetworkCallProposalController.outgoing?.stop(haber.callProposalInfo)
    }
    
    func getsCallAccept(_ haber: Haber) {
        NetworkCallProposalController.outgoing?.accept(haber.callProposalInfo)
    }
    
    func getsCallDecline(_ haber: Haber) {
        NetworkCallProposalController.outgoing?.decline(haber.callProposalInfo)
    }

    func getsOutgoingCallStart(_ haber: Haber) {
        NetworkCallController.incoming?.start(try! haber.callInfo())
        startCallOutput(haber, NetworkCallController.incoming, audio, video)
    }

    func getsIncomingCallStart(_ haber: Haber) {
        startCallOutput(haber, NetworkCallController.outgoing, audio, video)
    }

    func getsCallStop(_ haber: Haber) {
        NetworkCallController.incoming?.stop(try! haber.callInfo())
        NetworkCallController.outgoing?.stop(try! haber.callInfo())
        
        if haber.hasAudioSession {
            audio.remove(haber.audioSession.sid)
        }
        
        if haber.hasVideoSession {
            video.remove(haber.videoSession.sid)
        }
    }

    func getsAV(_ haber: Haber) {
        if (haber.av.hasAudio) {
            audio.process(haber.audioSession.sid, [AudioPart.NetworkPacket.rawValue: haber.av.audio.image.data as NSData])
        }
        
        if (haber.av.hasVideo) {
            video.process(haber.videoSession.sid, [VideoPart.NetworkPacket.rawValue: haber.av.video.image.data as NSData])
        }
    }

    func getsVideoSession(_ haber: Haber) {
        do {
            if haber.videoSession.hasActive && haber.videoSession.active {
                video.removeAll()

                try dispatch_sync_on_main {
                    guard let output = try videoSessionStart?(try haber.videoSessionInfo()!) else { return }
                    video.add(haber.videoSession.sid, output)
                }
            }
            else {
                videoSessionStop?(haber.videoSessionID!)
                video.remove(haber.videoSession.sid)
            }
        }
        catch {
            logNetworkError(error)
        }
    }

    func getsAudioSession(_ haber: Haber) {
        do {
            if haber.audioSession.hasActive && haber.audioSession.active {
                audio.removeAll()

                try dispatch_sync_on_main {
                    guard let output = try audioSessionStart?(try haber.audioSessionInfo()!) else { return }
                    audio.add(haber.audioSession.sid, output)
                }
            }
            else {
                audioSessionStop?(haber.audioSessionID!)
                audio.remove(haber.audioSession.sid)
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

        switch haber.which {
        case .av:
            logNetwork("read \(data.count) bytes for \(haber.which)")
        default:
            logNetworkPrior("read \(data.count) bytes for \(haber.which)")
        }
        
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
        case .callProposal:
            dispatch_async_network_call { self.getsCallProposal(haber) }
        case .callCancel:
            dispatch_async_network_call { self.getsCallCancel(haber) }
        case .callAccept:
            dispatch_async_network_call { self.getsCallAccept(haber) }
        case .callDecline:
            dispatch_async_network_call { self.getsCallDecline(haber) }
        case .callStartOutgoing:
            dispatch_async_network_call { self.getsOutgoingCallStart(haber) }
        case .callStartIncoming:
            dispatch_async_network_call { self.getsIncomingCallStart(haber) }
        case .callStop:
            dispatch_async_network_call { self.getsCallStop(haber) }
        default:
            logNetworkError("did not handle \(haber.which)")
        }
    }
}

extension Haber.Builder {
    
    func Fill(_ call: NetworkCallProposalInfo) throws -> Haber.Builder {
        return setCall(try Call.Builder()
            .setKey(call.id)
            .setFrom(call.from)
            .setTo(call.to)
            .setAudio(call.audio)
            .setVideo(call.video).build())
    }

    func Fill(_ session: NetworkAudioSessionInfo?, _ active: Bool) throws -> Haber.Builder {
        guard session != nil else { return self }
        return setAudioSession(try Avsession.Create(session, active))
    }

    func Fill(_ session: NetworkVideoSessionInfo?, _ active: Bool) throws -> Haber.Builder {
        guard session != nil else { return self }
        return setVideoSession(try Avsession.Create(session, active))
    }
}

extension Avsession {
    static func Create(_ session_: NetworkIOSessionInfo?, _ active: Bool) throws -> Avsession? {
        guard let session = session_ else { return nil }

        let sessionBuilder = Avsession.Builder()
            .setSid(session.id.sid)
            .setGid(session.id.gid)
            .setActive(active)
        
        if session.formatData != nil {
            sessionBuilder.setData(try session.formatData!() as Data)
        }
        
        return try sessionBuilder.build()
    }
}

extension Haber {
    
    static func Create(_ which: Haber.Which,
                       _ data: NetworkAudioSessionInfo,
                       _ active: Bool) throws -> Haber.Builder {
        return try Haber.Builder()
            .setWhich(which)
            .setTo(data.id.to)
            .setFrom(data.id.from)
            .Fill(data, active)
    }

    static func Create(_ which: Haber.Which,
                       _ data: NetworkVideoSessionInfo,
                       _ active: Bool) throws -> Haber.Builder {
        return try Haber.Builder()
            .setWhich(which)
            .setTo(data.id.to)
            .setFrom(data.id.from)
            .Fill(data, active)
    }

    static func Create(_ which: Haber.Which,
                       _ to: String,
                       _ data: NetworkCallProposalInfo) throws -> Haber.Builder {
        
        return try Haber.Builder()
            .setWhich(which)
            .setTo(to)
            .setFrom(Model.shared.username!)
            .Fill(data)
    }

    static func Create(_ which: Haber.Which,
                       _ to: String,
                       _ data: NetworkCallInfo) throws -> Haber.Builder {
        return try Haber.Builder()
            .setWhich(which)
            .setTo(to)
            .setFrom(Model.shared.username!)
            .Fill(data.proposal)
            .Fill(data.audioSession, true)
            .Fill(data.videoSession, true)
    }
    
    var audioSessionID: IOID? {
        get {
            guard hasAudioSession else { return nil }
            return IOID(from, to, audioSession.sid, audioSession.gid)
        }
    }

    var videoSessionID: IOID? {
        get {
            guard hasVideoSession else { return nil }
            return IOID(from, to, videoSession.sid, videoSession.gid)
        }
    }

    func audioSessionInfo() throws -> NetworkAudioSessionInfo? {
        guard hasAudioSession else { return nil }
        return NetworkAudioSessionInfo(audioSessionID!,
                                       audioSession.hasData ? factory(audioSession.data as NSData) : nil)
    }

    func videoSessionInfo() throws -> NetworkVideoSessionInfo? {
        guard hasVideoSession else { return nil }
        return NetworkVideoSessionInfo(videoSessionID!,
                                       videoSession.hasData ? factory(videoSession.data as NSData) : nil)
    }

    func callInfo() throws -> NetworkCallInfo {
        return NetworkCallInfo(callProposalInfo, try audioSessionInfo(), try videoSessionInfo())
    }
    
    var callProposalInfo: NetworkCallProposalInfo {
        get {
            return NetworkCallProposalInfo(self.call.key,
                                           self.call.from,
                                           self.call.to,
                                           self.call.hasAudio ? self.call.audio : false,
                                           self.call.hasVideo ? self.call.video : false)
        }
    }
}

func startCallOutput(_ haber: Haber, _ call: NetworkCallController?, _ audio: NetworkInput, _ video: NetworkInput) {
    var audio_: IODataProtocol?
    var video_: IODataProtocol?
    
    do {
        try call?.startOutput(try! haber.callInfo(), &audio_, &video_)
    }
    catch {
        logNetworkError(error)
    }
    
    if audio_ != nil {
        audio.add(haber.audioSession.sid, audio_!)
    }
    
    if video_ != nil {
        video.add(haber.videoSession.sid, video_!)
    }
}
