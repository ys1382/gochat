
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Queue
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func assert_audio_capture_queue() {
    assert(DispatchQueue.OnQueue(AV.shared.audioCaptureQueue))
}

func assert_video_capture_queue() {
    assert(DispatchQueue.OnQueue(AV.shared.videoCaptureQueue))
}

func assert_av_output_queue() {
    assert(DispatchQueue.OnQueue(AV.shared.avOutputQueue))
}

func dispatch_sync_av_output(_ block: FuncVV) {
    if DispatchQueue.OnQueue(AV.shared.avOutputQueue) {
        block()
    }
    else {
        AV.shared.avOutputQueue.sync { block() }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AV
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AV {
    
    static let shared = AV()
    static let defaultAudioFormatID = kAudioFormatMPEG4AAC
    static let defaultAudioInterval = 0.1
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IO
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    let audioCaptureQueue = DispatchQueue.CreateCheckable("chat.AudioCaptureQueue")
    let videoCaptureQueue = DispatchQueue.CreateCheckable("chat.VideoCaptureQueue")
    let avOutputQueue = DispatchQueue.CreateCheckable("chat.AVOutputQueue")

    private(set) var activeInput: IOSessionProtocol?
    private(set) var activeOutput = [String: IOSessionProtocol]()
    private(set) var activeIOSync = [String: IOSync]()
    
    init() {
        defaultVideoDimension = defaultVideoInputDevice?.activeFormat.dimensions
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func startInput(_ x: IOSessionProtocol?) throws {
        activeInput?.stop()
        activeInput = x
        try activeInput?.start()
    }

    var defaultVideoInputDevice: AVCaptureDevice? {
        return AVCaptureDevice.chatVideoDevice()
    }
    
    var defaultVideoDimension: CMVideoDimensions?

    var defaultVideoInputFormat: AVCaptureDeviceFormat? {
        get {
            guard let dimensions = defaultVideoDimension else { return nil }
            return defaultVideoInputDevice?.inputFormat(width: dimensions.width)
        }
    }

    var defaultAudioInputFormat: AudioStreamBasicDescription? {
        guard let inputFormat = AVAudioEngine().inputNode?.inputFormat(forBus: AudioBus.input) else { return nil }

        return AudioStreamBasicDescription.CreateVBR(AV.defaultAudioFormatID,
                                                           inputFormat.sampleRate/*8000*/,
                                                           1/*inputFormat.channelCount*/)
    }

    private func _defaultNetworkVideoInput(_ id: IOID,
                                    _ rotated: Bool,
                                    _ info: inout NetworkVideoSessionInfo?,
                                    _ session: inout AVCaptureSession.Accessor?,
                                    _ x: inout [VideoSessionProtocol]) {
        guard let device = AVCaptureDevice.chatVideoDevice() else { return }
        guard var outFormat = defaultVideoOutputFormat else { return }
        guard let inpFormat = defaultVideoInputFormat else { return }
        
        if rotated {
            outFormat.rotate()
        }
        
        let sessionEncoder =
            VideoEncoderSessionH264(
                inpFormat.dimensions,
                outFormat,
                VideoEncoderH264(
                    NetworkH264Serializer(
                        NetworkOutputVideo(id))))

        let videoInput =
            VideoInput(
                device,
                AV.shared.videoCaptureQueue,
                inpFormat,
                sessionEncoder)
        
        info = NetworkVideoSessionInfo(id, factory(outFormat))
        session = videoInput.sessionAccessor
        x.append(VideoSessionBroadcast([sessionEncoder, videoInput]))
    }
    
    func defaultNetworkVideoInput(_ id: IOID,
                           _ rotated: Bool,
                           _ info: inout NetworkVideoSessionInfo?,
                           _ session: inout AVCaptureSession.Accessor?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        
        _defaultNetworkVideoInput(id, rotated, &info, &session, &x)
        return create(x)
    }
    
    func defaultNetworkVideoInput(_ id: IOID,
                           _ preview: AVCaptureVideoPreviewLayer,
                           _ info: inout NetworkVideoSessionInfo?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        var y: AVCaptureSession.Accessor?
        
        _defaultNetworkVideoInput(id, false, &info, &y, &x)
        
        if y != nil {
            x.append(VideoPreview(preview, y!))
        }
        
        return create(x)
    }

    private func _defaultNetworkAudioInput(_ id: IOID,
                                           _ x: inout [IOSessionProtocol],
                                           _ formatOut: inout AudioFormat.Factory?) {
        
        guard let format = defaultAudioInputFormat else { return }
        
        let input =
            AudioInput(
                format,
                AV.defaultAudioInterval,
                NetworkAudioSerializer(
                    NetworkOutputAudio(id)))
        
        x.append(
            IOSessionSyncDispatcher(
                audioCaptureQueue,
                input))
        
        formatOut = input.format
    }
    
    func defaultNetworkAudioInput(_ id: IOID, _ info: inout NetworkAudioSessionInfo?) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        var format: AudioFormat.Factory?
        
        _defaultNetworkAudioInput(id, &x, &format)
        
        if format != nil {
            info = NetworkAudioSessionInfo(id, format!)
        }
        return create(x)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    var defaultVideoOutputFormat: VideoFormat? {
        get {
            guard let dimensions = defaultVideoInputFormat?.dimensions else { return nil }
            return VideoFormat(dimensions)
        }
    }

    func defaultIOSync(_ gid: String) -> IOSync {
        let result = activeIOSync[gid]
        
        if result != nil {
            return result!
        }
        
        activeIOSync[gid] = IOSync()
        
        return activeIOSync[gid]!
    }

    private func cleanupSync() {
        _ = activeIOSync.keys.map({ self.cleanupSync($0) })
    }

    private func cleanupSync(_ gid: String) {
        guard let sync = activeIOSync[gid] else { return }
        guard sync.active == false else { return }
        
        activeIOSync.removeValue(forKey: gid)
    }

    func startOutput(_ id: IOID, _ kind: IOKind, _ session: IOSessionProtocol) throws {
        try session.start()
        activeOutput[id.from + String(describing: kind)] = session
    }
    
    func stopOutput(_ id: IOID, _ kind: IOKind) {
        activeOutput[id.from + String(describing: kind)]?.stop()
        activeOutput.removeValue(forKey: id.from)
        cleanupSync(id.gid)
    }
    
    func stopAllOutput() {
        dispatch_sync_av_output {
            _ = activeOutput.map({ $0.value.stop() })
            activeOutput.removeAll()
            cleanupSync()
        }
    }
    
    func defaultNetworkVideoOutput(_ id: IOID,
                                   _ output: VideoOutputProtocol,
                                   _ session: inout IOSessionProtocol?) -> IODataProtocol {
        
        let time =
            VideoTimeSerializer(IOPart.Timestamp.rawValue)
        
        let sync =
            defaultIOSync(id.gid)
        
        let syncBus =
            IOSyncBus(
                id.sid,
                IOKind.Video,
                sync)
        
        let result =
            IODataSession(
                IODataAsyncDispatcher(
                    avOutputQueue,
                    NetworkH264Deserializer(
                        IOTimebaseReset(
                            sync,
                            time,
                            syncBus))))
        
        let syncedOutput =
            IOSyncedDataSession(
                VideoDecoderH264Data(
//                    VideoDecoderH264(
                    output))
        
        sync.add(
            IOKind.Video,
            time,
            IOSyncedDataDispatcher(
                avOutputQueue,
                syncedOutput))

        session = create([result, syncBus, syncedOutput, session])
        
        return result
    }

    func defaultNetworkVideoOutput(_ id: IOID,
                                   _ layer: AVSampleBufferDisplayLayer,
                                   _ session: inout IOSessionProtocol?) -> IODataProtocol {
        let output = VideoOutput(layer)
        
        session = output
        
        return AV.shared.defaultNetworkVideoOutput(id,
                                                   output,
                                                   &session)
    }
    
    func startDefaultNetworkVideoOutput(_ id: IOID,
                                        _ output: VideoOutputProtocol,
                                        _ session_: IOSessionProtocol?) throws -> IODataProtocol {
        var session = session_
        let result = AV.shared.defaultNetworkVideoOutput(id, output, &session)
        
        if session != nil {
            try startOutput(id, IOKind.Video, session!)
        }
        
        return result
    }
    
    func startDefaultNetworkVideoOutput(_ id: IOID,
                                        _ layer: AVSampleBufferDisplayLayer) throws -> IODataProtocol {
        return try AV.shared.startDefaultNetworkVideoOutput(id,
                                                            VideoOutput(layer),
                                                            nil)
    }
    
    func defaultNetworkAudioOutput(_ id: IOID,
                                   _ format: AudioFormat,
                                   _ session: inout IOSessionProtocol?) -> IODataProtocol {
        let time =
            AudioTimeSerializer(AudioPart.NetworkPacket.rawValue, MemoryLayout<UInt32>.size)
        
        let output =
            AudioOutput(
                factory(format),
                avOutputQueue)
        
        let decoder =
            AudioDecoder(
                factory(format),
                output.format,
                output)
        
        let sync =
            defaultIOSync(
                id.gid)
        
        let syncBus =
            IOSyncBus(
                id.sid,
                IOKind.Audio,
                sync)
        
        let result =
            IODataSession(
                IODataAsyncDispatcher(
                    avOutputQueue,
                    IOTimebaseReset(
                        sync,
                        time,
                        syncBus)))
        
        let syncedOutput =
            IOSyncedDataSession(
                IOSyncSubdataSkip(
                    NetworkAudioDeserializer(
                        decoder)))
        
        sync.add(
            IOKind.Audio,
            time,
            syncedOutput)
        
        session = create([result, output, syncedOutput, decoder, syncBus])
        
        return result
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Playback
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    var defaultAudioInputUncompressedFormat: AudioStreamBasicDescription? {
        guard let inputFormat = AVAudioEngine().inputNode?.inputFormat(forBus: AudioBus.input) else { return nil }
        var format = inputFormat.streamDescription.pointee
        
        format.mChannelsPerFrame = 1
        return format
    }

    func startAudioUncompressedPlayback() throws {
        guard let format = defaultAudioInputUncompressedFormat else { return }
        
        let input =
            AudioInput(
                format,
                AV.defaultAudioInterval)
        
        let output =
            AudioOutput(
                input.format,
                AV.shared.audioCaptureQueue)
        
        input.output =
            NetworkAudioSerializer(
                NetworkAudioDeserializer(
                    output))
        
        try audioCaptureQueue.sync {
            try AV.shared.startInput(create([output, input]))
        }
    }

    func startAudioCompressedPlayback() throws {
        guard let format = defaultAudioInputFormat else { return }

        let input =
            AudioInput(
                format,
                AV.defaultAudioInterval)
        
        let output =
            AudioOutput(
                input.format,
                AV.shared.audioCaptureQueue)
        
        let decoder =
            AudioDecoder(
                input.format,
                output.format,
                output)
        
        input.output =
            NetworkAudioSerializer(
                NetworkAudioDeserializer(
                    decoder))
        
        try audioCaptureQueue.sync {
            try AV.shared.startInput(create([input, output, decoder]))
        }
    }
}
