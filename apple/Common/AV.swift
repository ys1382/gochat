
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Assertions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func assert_audio_capture_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.audioCaptureQueue))
}

func assert_video_capture_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.videoCaptureQueue))
}

func assert_av_output_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.avOutputQueue))
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AV
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AV {
    
    static let shared = AV()
    static let defaultAudioFormat = kAudioFormatMPEG4AAC
    static let defaultAudioInterval = 0.1
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IO
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    let audioCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.AudioCaptureQueue")
    let videoCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.VideoCaptureQueue")
    let avOutputQueue = ChatDispatchQueue.CreateCheckable("chat.AVOutputQueue")

    var defaultVideoDimention: CMVideoDimensions? = AVCaptureDevice.chatVideoDevice()?.dimentions
    
    private(set) var activeInput: IOSessionProtocol?
    private(set) var activeAudioOutput = [String: IOSessionProtocol]()
    private(set) var activeVideoOutput = [String: IOSessionProtocol]()
    private(set) var activeIOSync = [String: IOSync]()
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func _defaultVideoInput(_ id: IOID,
                                    _ session: inout AVCaptureSession.Factory?,
                                    _ x: inout [VideoSessionProtocol]) {
        guard let device = AVCaptureDevice.chatVideoDevice() else { return }

        let inpFormat = defaultVideoInputFormat()
        let outFormat = defaultVideoOutputFormat()
        
        let sessionEncoder =
            VideoEncoderSessionH264(
                inpFormat.dimentions,
                outFormat,
                VideoEncoderH264(
                    NetworkH264Serializer(
                        NetworkOutputVideo(id))))
        let sessionNetwork = NetworkOutputVideoSession(id, outFormat)

        let videoInput =
            VideoInput(
                device,
                AV.shared.videoCaptureQueue,
                outFormat,
                sessionEncoder)
        
        let result =
            VideoSessionAsyncDispatcher(
                videoCaptureQueue,
                VideoSessionBroadcast([
                    sessionEncoder,
                    videoInput,
                    sessionNetwork]))
        
        session = { () in return videoInput.session }
        x.append(result)
    }

    private func _defaultAudioInput(_ id: IOID, _ x: inout [IOSessionProtocol]) {
        
        let input =
            AudioInput(
                AV.defaultAudioFormat,
                AV.defaultAudioInterval,
                NetworkAACSerializer(
                    NetworkOutputAudio(id)))

        let sessionNetwork =
            NetworkOutputAudioSession(id, input.format)

        let result =
            IOSessionAsyncDispatcher(
                audioCaptureQueue,
                IOSessionBroadcast([
                    input,
                    sessionNetwork]))
        
        x.append(result)
    }

    func startInput(_ x: IOSessionProtocol?) throws {
        activeInput?.stop()
        activeInput = x
        try activeInput?.start()
    }

    func defaultVideoInputFormat() -> VideoFormat {
        guard let dimentions = AVCaptureDevice.chatVideoDevice()?.dimentions else {
            return VideoFormat()
        }
        
        return VideoFormat(dimentions)
    }
    
    func defaultVideoInput(_ id: IOID,
                           _ session: inout AVCaptureSession.Factory?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        
        _defaultVideoInput(id, &session, &x)
        return create(x)
    }

    func defaultVideoInput(_ id: IOID,
                           _ preview: AVCaptureVideoPreviewLayer) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        var y: AVCaptureSession.Factory?
        
        _defaultVideoInput(id, &y, &x)
        
        if y != nil {
            x.append(VideoPreview(preview, y!))
        }
        
        return create(x)
    }

    func defaultAudioInput(_ id: IOID) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        _defaultAudioInput(id, &x)
        return create(x)
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func defaultVideoOutputFormat() -> VideoFormat {
        return VideoFormat(defaultVideoDimention!)
    }
    
    func defaultIOSync(_ sid: String) -> IOSync {
        let result = activeIOSync[sid]
        
        if result != nil {
            return result!
        }
        
        activeIOSync[sid] = IOSync()
        
        return activeIOSync[sid]!
    }

    func startAudioOutput(_ id: IOID, _ session: IOSessionProtocol) throws {
        try session.start()
        activeAudioOutput[id.from] = session
    }
    
    func stopAudioOutput(_ id: IOID) {
        activeAudioOutput[id.from]?.stop()
        activeAudioOutput.removeValue(forKey: id.from)
    }
    
    func stopAllAudioOutput() {
        _ = activeAudioOutput.map({ $0.value.stop() })
        activeAudioOutput.removeAll()
    }
    
    func defaultNetworkInputVideo(_ id: IOID,
                                  _ output: VideoOutputProtocol) -> IODataProtocol {
        
        let sync =
            defaultIOSync(id.gid)
        
        let syncBus =
            IOSyncBus(
                IOKind.Video,
                sync)
        
        let result =
            IODataDispatcher(
                avOutputQueue,
                NetworkH264Deserializer(
                    syncBus))
        
        sync.add(
            IOKind.Video,
            VideoTimeDeserializer(H264Part.Time.rawValue),
                VideoDecoderH264(
                    output))

        return result
    }

    func defaultNetworkOutputAudio(_ id: IOID,
                                   _ format: AudioFormat,
                                   _ session: inout IOSessionProtocol?) -> IODataProtocol {
        let output =
            AudioOutput(format, AV.defaultAudioFormat, AV.defaultAudioInterval)
        
        let sync =
            defaultIOSync(id.gid)
        
        let syncBus =
            IOSyncBus(
                IOKind.Audio,
                sync)
        
        let result =
            IODataDispatcher(
                avOutputQueue,
                syncBus)
        
        sync.add(
            IOKind.Audio,
            AudioTimeDeserializer(AACPart.NetworkPacket.rawValue),
            NetworkAACDeserializer(
                output))
        
        session = output
        
        return result
    }
    
    func setupDefaultNetworkInputAudio(_ platformSession: IOSessionProtocol?) {        
        let audioSessionStart = { (_ id: IOID, format: AudioFormat) throws -> IODataProtocol in
            var session: IOSessionProtocol? = nil
            let result = AV.shared.defaultNetworkOutputAudio(id, format, &session)
            
            if platformSession != nil && session != nil {
                let shared = session!
                let broadcast = create([platformSession!, shared])
                
                session = broadcast
            }
            
            if session == nil {
                session = platformSession
            }
            
            if session != nil {
                self.stopAllAudioOutput()
                try self.startAudioOutput(id, session!)
            }
            
            return result
        }
        
        let audioSessionStop = { (_ id: IOID) in
            self.stopAudioOutput(id)
        }
        
        Backend.shared.audioSessionStart = { (_ id: IOID, format: AudioFormat) in
            var result: IODataProtocol?
            
            self.avOutputQueue.sync {
                do {
                    result = try audioSessionStart(id, format)
                }
                catch {
                    logIOError(error)
                }
            }
            
            return result
        }
        
        Backend.shared.audioSessionStop = { (_ id: IOID) in
            self.avOutputQueue.sync {
                audioSessionStop(id)
            }
        }
    }
}
