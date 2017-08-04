import Foundation

// for user of Voip.proto
// todo: add file, AV
class VoipBackend {

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
            case        .text: Model.shared.didReceiveText(body: voip.payload, from: peerId)
            default:    print("did not handle \(voip.which)")
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
    
}
