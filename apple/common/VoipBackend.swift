import Foundation

// for user of Voip.proto
// todo: add file, AV
class VoipBackend {

    private static var audio = NetworkInput()
    private static var video = NetworkInput()

    static var videoSessionStart: ((NetworkVideoSessionInfo) throws ->IODataProtocol?)?
    static var videoSessionStop: ((IOID)->Void)?
    
    static var audioSessionStart: ((NetworkAudioSessionInfo) throws ->IODataProtocol?)?
    static var audioSessionStop: ((IOID)->Void)?
    
    static func sendText(_ body: String, peerId: String) {
        do {
            let data = try Voip.Builder().setWhich(.text).setPayload(body.data(using: .utf8)!).build().data()
            WireBackend.shared.send(data: data, peerId: peerId)
        } catch {
            print(error.localizedDescription)
        }
    }

    static func didReceiveFromPeer(_ data: Data, from peerId: String) {
        guard let voip = try? Voip.parseFrom(data:data) else {
            print("Could not deserialize voip")
            return
        }
        
        print("read \(data.count) bytes for \(voip.which) from \(peerId)")
        switch voip.which {
        case .text: Model.shared.didReceiveText(body: voip.payload, from: peerId)
        case .av: getsAV(voip)
        case .audioSession: getsAudioSession(voip)
        case .videoSession: getsVideoSession(voip)
        case .callProposal:
            dispatch_async_network_call { VoipBackend.getsCallProposal(voip) }
        case .callCancel:
            dispatch_async_network_call { VoipBackend.getsCallCancel(voip) }
        case .callAccept:
            dispatch_async_network_call { VoipBackend.getsCallAccept(voip) }
        case .callDecline:
            dispatch_async_network_call { VoipBackend.getsCallDecline(voip) }
        case .callStartOutgoing:
            dispatch_async_network_call { VoipBackend.getsOutgoingCallStart(voip) }
        case .callStartIncoming:
            dispatch_async_network_call { VoipBackend.getsIncomingCallStart(voip) }
        case .callQuality:
            dispatch_async_network_call { VoipBackend.getsCallQuality(voip) }
        case .callStop:
            dispatch_async_network_call { VoipBackend.getsCallStop(voip) }
            
        default:
            logNetworkError("did not handle \(voip.which)")
        }
    }
    
    static func sendCallProposal(_ to: String, _ info: NetworkCallProposalInfo) {
        do {
            let data = try Voip.Create(.callProposal, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendCallCancel(_ to: String, _ info: NetworkCallProposalInfo) {
        do {
            let data = try Voip.Create(.callCancel, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendCallAccept(_ to: String, _ info: NetworkCallProposalInfo) {
        do {
            let data = try Voip.Create(.callAccept, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendCallDecline(_ to: String, _ info: NetworkCallProposalInfo) {
        do {
            let data = try Voip.Create(.callDecline, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendOutgoingCallStart(_ to: String, _ info: NetworkCallInfo) {
        do {
            let data = try Voip.Create(.callStartOutgoing, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendIncomingCallStart(_ to: String, _ info: NetworkCallInfo) {
        do {
            let data = try Voip.Create(.callStartIncoming, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendCallChangeQuality(_ to: String, _ info: NetworkCallInfo, _ diff: Int32) {
        do {
            let data = try Voip.Create(.callStartIncoming, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendCallStop(_ to: String, _ info: NetworkCallInfo) {
        do {
            let data = try Voip.Create(.callStop, to, info).build().data()
            WireBackend.shared.send(data: data, peerId: to)
        } catch {
            print(error.localizedDescription)
        }        
    }
    
    static func sendVideoSession(_ session: NetworkVideoSessionInfo, _ active: Bool) {
        do {
            let data = try Voip.Create(.videoSession, session, active).build().data()
            WireBackend.shared.send(data: data, peerId: session.id.to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendAudioSession(_ session: NetworkAudioSessionInfo, _ active: Bool) {
        do {
            let data = try Voip.Create(.audioSession, session, active).build().data()
            WireBackend.shared.send(data: data, peerId: session.id.to)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static func sendVideo(_ id: IOID, _ data: NSData, _ callback: @escaping FuncVV) {
        assert_video_capture_queue()
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try VideoSample.Builder().setImage(image).build()
            let av = try Av.Builder().setVideo(media).build()
            
            let data = try Voip.Builder()
                        .setWhich(.av)
                        .setAv(av)
                        .setVideoSession(try Avsession.Builder().setSid(id.sid).build()).build().data()
            WireBackend.shared.send(data: data, peerId: id.to)
        }
        catch {
            logNetworkError(error)
        }
    }
    
    static func sendAudio(_ id: IOID, _ data: NSData, _ callback: @escaping FuncVV) {
        assert_audio_capture_queue()
        
        do {
            let image = try Image.Builder().setData(data as Data).build()
            let media = try AudioSample.Builder().setImage(image).build()
            let av = try Av.Builder().setAudio(media).build()
            
            let data = try Voip.Builder()
                                .setWhich(.av)
                                .setAv(av)
                                .setAudioSession(try Avsession.Builder().setSid(id.sid).build()).build().data()
            
            WireBackend.shared.send(data: data, peerId: id.to)
        }
        catch {
            logNetworkError(error)
        }
    }
    
    static func getsCallProposal(_ voip: Voip) {
        NetworkCallProposalController.incoming?.start(voip.callProposalInfo)
    }
    
    static func getsCallCancel(_ voip: Voip) {
        NetworkCallProposalController.incoming?.stop(voip.callProposalInfo)
        NetworkCallProposalController.outgoing?.stop(voip.callProposalInfo)
    }
    
    static func getsCallAccept(_ voip: Voip) {
        NetworkCallProposalController.outgoing?.accept(voip.callProposalInfo)
    }
    
    static func getsCallDecline(_ voip: Voip) {
        NetworkCallProposalController.outgoing?.decline(voip.callProposalInfo)
    }
    
    static func getsOutgoingCallStart(_ voip: Voip) {
        NetworkCallController.incoming?.start(try! voip.callInfo())
        startCallOutput(voip, NetworkCallController.incoming, audio, video)
    }
    
    static func getsIncomingCallStart(_ voip: Voip) {
        startCallOutput(voip, NetworkCallController.outgoing, audio, video)
    }
    
    static func getsCallQuality(_ voip: Voip) {
        changeCallQuality(try! voip.callInfo(), Int(voip.avQuality.diff))
    }
    
    static func getsCallStop(_ voip: Voip) {
        NetworkCallController.incoming?.stop(try! voip.callInfo())
        NetworkCallController.outgoing?.stop(try! voip.callInfo())
        
        if voip.hasAudioSession {
            audio.remove(voip.audioSession.sid)
        }
        
        if voip.hasVideoSession {
            video.remove(voip.videoSession.sid)
        }
    }
    
    static func getsAV(_ voip: Voip) {
        if (voip.av.hasAudio) {
            audio.process(voip.audioSession.sid, voip.av.audio.image.data as NSData)
        }
        
        if (voip.av.hasVideo) {
            video.process(voip.videoSession.sid, voip.av.video.image.data as NSData)
        }
    }
    
    static func getsVideoSession(_ voip: Voip) {
        do {
            if voip.videoSession.hasActive && voip.videoSession.active {
                video.removeAll()
                
                try dispatch_sync_on_main {
                    guard let output = try videoSessionStart?(try voip.videoSessionInfo()!) else { return }
                    video.add(voip.videoSession.sid, output)
                }
            }
            else {
                videoSessionStop?(voip.videoSessionID!)
                video.remove(voip.videoSession.sid)
            }
        }
        catch {
            logNetworkError(error)
        }
    }
    
    static func getsAudioSession(_ voip: Voip) {
        do {
            if voip.audioSession.hasActive && voip.audioSession.active {
                audio.removeAll()
                
                try dispatch_sync_on_main {
                    guard let output = try audioSessionStart?(try voip.audioSessionInfo()!) else { return }
                    audio.add(voip.audioSession.sid, output)
                }
            }
            else {
                audioSessionStop?(voip.audioSessionID!)
                audio.remove(voip.audioSession.sid)
            }
        }
        catch {
            logNetworkError(error)
        }
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

extension Voip.Builder {
    func Fill(_ call: NetworkCallProposalInfo) throws -> Voip.Builder {
        return setCall(try Call.Builder()
            .setKey(call.id)
            .setFrom(call.from)
            .setTo(call.to)
            .setAudio(call.audio)
            .setVideo(call.video).build())
    }
    
    func Fill(_ session: NetworkAudioSessionInfo?, _ active: Bool) throws -> Voip.Builder {
        guard session != nil else { return self }
        return setAudioSession(try Avsession.Create(session, active))
    }
    
    func Fill(_ session: NetworkVideoSessionInfo?, _ active: Bool) throws -> Voip.Builder {
        guard session != nil else { return self }
        return setVideoSession(try Avsession.Create(session, active))
    }
    
    func FillQuality(_ diff: Int32) throws -> Voip.Builder {
        setAvQuality(try Avquality.Builder()
            .setDiff(diff).build())
        
        return self
    }
    
}

extension Voip {
    static func Create(_ which: Voip.Which,
                       _ data: NetworkAudioSessionInfo,
                       _ active: Bool) throws -> Voip.Builder {
        return try Voip.Builder()
            .setWhich(which)
            .Fill(data, active)
    }
    
    static func Create(_ which: Voip.Which,
                       _ data: NetworkVideoSessionInfo,
                       _ active: Bool) throws -> Voip.Builder {
        return try Voip.Builder()
            .setWhich(which)
            .Fill(data, active)
    }
    
    static func Create(_ which: Voip.Which,
                       _ to: String,
                       _ data: NetworkCallProposalInfo) throws -> Voip.Builder {
        
        return try Voip.Builder()
            .setWhich(which)
            .Fill(data)
    }
    
    static func Create(_ which: Voip.Which,
                       _ to: String,
                       _ data: NetworkCallInfo) throws -> Voip.Builder {
        return try Voip.Builder()
            .setWhich(which)
            .Fill(data.proposal)
            .Fill(data.audioSession, true)
            .Fill(data.videoSession, true)
    }
    
    static func CreateQuality(_ to: String,
                              _ call: NetworkCallInfo,
                              _ diff: Int32) throws -> Voip.Builder {
        return try Create(.callQuality, to, call).FillQuality(diff)
    }
    
    var audioSessionID: IOID? {
        get {
            guard hasAudioSession else { return nil }
            return IOID(call.from, call.to, audioSession.sid, audioSession.gid)
        }
    }
    
    var videoSessionID: IOID? {
        get {
            guard hasVideoSession else { return nil }
            return IOID(call.from, call.to, videoSession.sid, videoSession.gid)
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

func startCallOutput(_ voip: Voip, _ call: NetworkCallController?, _ audio: NetworkInput, _ video: NetworkInput) {
    var audio_: IODataProtocol?
    var video_: IODataProtocol?
    
    do {
        try call?.startOutput(try! voip.callInfo(), &audio_, &video_)
    }
    catch {
        logNetworkError(error)
    }
    
    if audio_ != nil {
        audio.add(voip.audioSession.sid, audio_!)
    }
    
    if video_ != nil {
        video.add(voip.videoSession.sid, video_!)
    }
}
