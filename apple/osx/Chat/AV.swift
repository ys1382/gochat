
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

    init() {
        defaultVideoDimension = defaultVideoInputDevice?.activeFormat.dimensions
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
                                           _ context: IOInputContext,
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

        let serializer =
            NetworkH264Serializer(
                NetworkOutputVideo(id, context.qos, context.balancer))
        
        let sessionEncoder =
            VideoEncoderSessionH264(
                inpFormat.dimensions,
                outFormat,
                serializer)

        let videoInput =
            VideoInput(
                device,
                AV.shared.videoCaptureQueue,
                inpFormat,
                sessionEncoder)
        
        let videoInputQoS
            = VideoInputQoS(inpFormat,
                            VideoSessionBroadcast([videoInput, sessionEncoder]))
        
        let qos =
            IOQoSDispatcher(
                videoCaptureQueue,
                IOQoSBroadcast([videoInputQoS, serializer]))
        
        context.qos.add(qos)
        info = NetworkVideoSessionInfo(id, factory(outFormat))
        session = videoInput.sessionAccessor
        x.append(VideoSessionBroadcast([sessionEncoder, videoInput]))
    }
    
    func defaultNetworkVideoInput(_ id: IOID,
                                  _ context: IOInputContext,
                                  _ rotated: Bool,
                                  _ info: inout NetworkVideoSessionInfo?,
                                  _ session: inout AVCaptureSession.Accessor?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        
        _defaultNetworkVideoInput(id, context, rotated, &info, &session, &x)
        return broadcast(x)
    }
    
    func defaultNetworkVideoInput(_ id: IOID,
                                  _ context: IOInputContext,
                                  _ preview: AVCaptureVideoPreviewLayer,
                                  _ info: inout NetworkVideoSessionInfo?) -> VideoSessionProtocol? {
        var x = [VideoSessionProtocol]()
        var y: AVCaptureSession.Accessor?
        
        _defaultNetworkVideoInput(id, context, false, &info, &y, &x)
        
        if y != nil {
            x.append(VideoPreview(preview, y!))
        }
        
        return broadcast(x)
    }

    private func _defaultNetworkAudioInput(_ id: IOID,
                                           _ context: IOInputContext,
                                           _ x: inout [IOSessionProtocol],
                                           _ formatOut: inout AudioFormat.Factory?) {
        
        guard let format = defaultAudioInputFormat else { return }
        
        let serializer =
            NetworkAudioSerializer(
                NetworkOutputAudio(id, context.qos, context.balancer))
        
        let input =
            AudioInput(
                format,
                AV.defaultAudioInterval,
                serializer)
        
        x.append(
            IOSessionSyncDispatcher(
                audioCaptureQueue,
                input))
        
        let qos =
            IOQoSDispatcher(
                audioCaptureQueue,
                serializer)
        
        context.qos.add(qos)
        formatOut = input.format
    }
    
    func defaultNetworkAudioInput(_ id: IOID,
                                  _ context: IOInputContext,
                                  _ info: inout NetworkAudioSessionInfo?) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        var format: AudioFormat.Factory?
        
        _defaultNetworkAudioInput(id, context, &x, &format)
        
        if format != nil {
            info = NetworkAudioSessionInfo(id, format!)
        }
        return broadcast(x)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    var defaultVideoOutputFormat: VideoFormat? {
        get {
            guard let format = defaultVideoInputFormat else { return nil }
            return VideoFormat(format)
        }
    }

    func defaultNetworkVideoOutput(_ id: IOID,
                                   _ context: IOOutputContext,
                                   _ output: VideoOutputProtocol,
                                   _ session: IOSessionProtocol? = nil) -> IOOutputContext {
        
        let time =
            VideoTimeSerializer(NetworkDeserializer.timeIndex)
        
        let balancedOutput =
            IOBalancedDataSession(
                NetworkH264Deserializer(
//                    VideoDecoderH264(
                    output))

        let sheduler =
            IOSheduler(
                IOKind.Video,
                balancedOutput)
        
        let balancer =
            IODataAdapter4Balancer(
                time,
                context.balancer!,
                sheduler)

        let resultSession =
            IODataSession(
                IOTimebaseReset(
                    context.timebase!,
                    time,
                    balancer))
        
        let result =
            IODataAsyncDispatcher(
                avOutputQueue,
                resultSession)
        
        return IOOutputContext(id,
                               broadcast([sheduler, resultSession, balancedOutput, session])!,
                               result,
                               context)
    }

    func defaultNetworkVideoOutput(_ id: IOID,
                                   _ context: IOOutputContext,
                                   _ layer: AVSampleBufferDisplayLayer,
                                   _ session: IOSessionProtocol? = nil) -> IOOutputContext {
        let output = VideoOutput(layer)
        
        return AV.shared.defaultNetworkVideoOutput(id,
                                                   context,
                                                   output,
                                                   output)
    }
    
    func defaultNetworkAudioOutput(_ id: IOID,
                                   _ format: AudioFormat,
                                   _ context: IOOutputContext,
                                   _ session: IOSessionProtocol? = nil) -> IOOutputContext {
        let time =
            AudioTimeUpdater(NetworkDeserializer.timeIndex)
        
        let output =
            AudioOutput(
                factory(format),
                avOutputQueue)
        
        let decoder =
            AudioDecoder(
                factory(format),
                output.format,
                output)
        
        let balancedOutput =
            IOBalancedDataSession(
                IOBalanceSubdataSkip(
                    NetworkAudioDeserializer(
                        decoder)))

        let sheduler =
            IOSheduler(
                IOKind.Audio,
                balancedOutput)
        
        let balancer =
            IODataAdapter4Balancer(
                time,
                context.balancer!,
                sheduler)
        
        let resultSession =
            IODataSession(
                IOTimebaseReset(
                    context.timebase!,
                    time,
                    balancer))
        
        let result =
                IODataAsyncDispatcher(
                    avOutputQueue,
                    resultSession)
        
        return IOOutputContext(id,
                               broadcast([sheduler, resultSession, output, balancedOutput, decoder, session])!,
                               result,
                               context)
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

    func audioUncompressedPlayback() throws -> IOSessionProtocol? {
        guard let format = defaultAudioInputUncompressedFormat else { return nil }
        
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
        
        return broadcast([output, input])
    }

    func audioCompressedPlayback() throws -> IOSessionProtocol? {
        guard let format = defaultAudioInputFormat else { return nil }

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
        
        return broadcast([input, output, decoder])
    }
}
