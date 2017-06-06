
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Assertions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func assert_av_capture_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.avCaptureQueue))
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

    let avCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.AVCaptureQueue")
    let avOutputQueue = ChatDispatchQueue.CreateCheckable("chat.AVOutputQueue")

    var defaultVideoDimention: CMVideoDimensions? = AVCaptureDevice.chatVideoDevice()?.dimentions
    
    private(set) var activeInput: IOSessionProtocol?
    private(set) var activeAudioOutput = [String: IOSessionProtocol]()
    private(set) var activeVideoOutput = [String: IOSessionProtocol]()
    private(set) var activeIOSync = [String: IOSync]()
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func _defaultVideoInput(_ to: String,
                                    _ session: inout AVCaptureSession.Factory?,
                                    _ x: inout [VideoSessionProtocol]) {
        guard let device = AVCaptureDevice.chatVideoDevice() else { return }

        let sid = Backend.shared.createAVSessionID(to)
        
        let inpFormat = defaultVideoInputFormat()
        let outFormat = defaultVideoOutputFormat()
        
        let sessionEncoder = VideoEncoderSessionH264(inpFormat.dimentions, outFormat)
        let sessionNetwork = NetworkOutputVideoSession(to, sid, outFormat)

        let videoInput =
            VideoInput(
                device,
                AV.shared.avCaptureQueue,
                VideoEncoderH264(
                    sessionEncoder,
                    NetworkH264Serializer(
                        NetworkOutputVideo(to, sid))))
        
        session = { () in return videoInput.session }
        x.append(VideoSessionBroadcast([sessionEncoder, videoInput, sessionNetwork]))
    }

    private func _defaultAudioInput(_ to: String, _ x: inout [IOSessionProtocol]) {
        
        let sid =
            Backend.shared.createAVSessionID(to)

        let input =
            AudioInput(
                AV.defaultAudioFormat,
                AV.defaultAudioInterval,
                NetworkAACSerializer(
                    NetworkOutputAudio(to, sid)))

        let sessionNetwork =
            NetworkOutputAudioSession(to, sid, input.format)

        x.append(IOSessionBroadcast([input, sessionNetwork]))
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
    
    func defaultVideoInput(_ to: String,
                           _ session: inout AVCaptureSession.Factory?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        
        _defaultVideoInput(to, &session, &x)
        return create(x)
    }

    func defaultVideoInput(_ to: String,
                           _ preview: AVCaptureVideoPreviewLayer) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        var y: AVCaptureSession.Factory?
        
        _defaultVideoInput(to, &y, &x)
        
        if y != nil {
            x.append(VideoPreview(preview, y!))
        }
        
        return create(x)
    }

    func defaultAudioInput(_ to: String) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        _defaultAudioInput(to, &x)
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
        
        activeIOSync[sid] = IOSync(.Audio)
        
        return activeIOSync[sid]!
    }

    func startAudioOutput(_ from: String, _ session: IOSessionProtocol) throws {
        try session.start()
        activeAudioOutput[from] = session
    }
    
    func stopAudioOutput(_ from: String) {
        activeAudioOutput[from]?.stop()
        activeAudioOutput.removeValue(forKey: from)
    }
    
    func stopAllAudioOutput() {
        _ = activeAudioOutput.map({ $0.value.stop() })
        activeAudioOutput.removeAll()
    }
    
    func defaultNetworkInputVideo(_ sid: String,
                                  _ output: VideoOutputProtocol) -> IODataProtocol {
        
        let sync =
            defaultIOSync(sid)
        
        let syncBus =
            IOSyncBus(
                IOKind.Video,
                VideoTimeDeserializer(H264Part.Time.rawValue),
                sync)
        
        let result =
            IODataDispatcher(
                avOutputQueue,
                syncBus)
        
        sync.add(
            IOKind.Video,
            NetworkH264Deserializer(
                VideoDecoderH264(
                    output)))

        return result
    }

    func defaultNetworkOutputAudio(_ sid: String,
                                   _ format: AudioFormat,
                                   _ session: inout IOSessionProtocol?) -> IODataProtocol {
        let output =
            AudioOutput(format, AV.defaultAudioFormat, AV.defaultAudioInterval)
        
        let sync =
            defaultIOSync(sid)
        
        let syncBus =
            IOSyncBus(
                IOKind.Audio,
                AudioTimeDeserializer(AACPart.NetworkPacket.rawValue),
                sync)
        
        let result =
            IODataDispatcher(
                avOutputQueue,
                syncBus)
        
        sync.add(
            IOKind.Audio,
            NetworkAACDeserializer(
                output))
        
        session = output
        
        return result
    }
    
    func setupDefaultNetworkInputAudio(_ platformSession: IOSessionProtocol?) {        
        let audioSessionStart = { (_ from: String, format: AudioFormat) throws -> IODataProtocol in
            var session: IOSessionProtocol? = nil
            let result = AV.shared.defaultNetworkOutputAudio(from, format, &session)
            
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
                try self.startAudioOutput(from, session!)
            }
            
            return result
        }
        
        let audioSessionStop = { (_ from: String) in
            self.stopAudioOutput(from)
        }
        
        Backend.shared.audioSessionStart = { (_ from: String, format: AudioFormat) in
            var result: IODataProtocol?
            
            self.avOutputQueue.sync {
                do {
                    result = try audioSessionStart(from, format)
                }
                catch {
                    logIOError(error)
                }
            }
            
            return result
        }
        
        Backend.shared.audioSessionStop = { (_ from: String) in
            self.avOutputQueue.sync {
                audioSessionStop(from)
            }
        }
    }
}
