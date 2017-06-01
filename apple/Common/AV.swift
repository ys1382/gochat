
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
    static let defaultAudioFormat = kAudioFormatMPEG4AAC_ELD
    static let defaultAudioInterval = 0.1
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IO
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    let avCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.AVCaptureQueue")
    let avOutputQueue = ChatDispatchQueue.CreateCheckable("chat.AVOutputQueue")

    private(set) var activeInput: IOSessionProtocol?
    
    private(set) var activeAudioOutput: IOSessionProtocol?
    private(set) var activeVideoOutput: IOSessionProtocol?
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    private func _defaultVideoInput(_ to: String,
                                    _ preview: AVCaptureVideoPreviewLayer,
                                    _ x: inout [IOSessionProtocol]) {
        guard let device = AVCaptureDevice.chatVideoDevice() else { return }
        let dimention = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let format = VideoFormat(dimention)
        
        let sessionEncoder = VideoEncoderSessionH264(dimention, dimention)
        let sessionNetwork = NetworkOutputVideoSession(to, format)

        let input =
            VideoInput(
                device,
                preview,
                AV.shared.avCaptureQueue,
                VideoEncoderH264(
                    sessionEncoder,
                    NetworkH264Serializer(
                        NetworkOutputVideo(to))))
        
        x.append(IOSessionBroadcast([sessionEncoder, input, sessionNetwork]))
    }

    private func _defaultAudioInput(_ to: String, _ x: inout [IOSessionProtocol]) {
        
        let input =
            AudioInput(
                AV.defaultAudioFormat,
                AV.defaultAudioInterval,
                NetworkAACSerializer(
                    NetworkOutputAudio(to)))

        let sessionNetwork =
            NetworkOutputAudioSession(to, input.format)

        x.append(IOSessionBroadcast([input, sessionNetwork]))
    }

    func startInput(_ x: IOSessionProtocol?) throws {
        activeInput?.stop()
        activeInput = x
        try activeInput?.start()
    }

    func defaultVideoInput(_ to: String, _ preview: AVCaptureVideoPreviewLayer) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        _defaultVideoInput(to, preview, &x)
        return create(x)
    }

    func defaultAudioInput(_ to: String) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        _defaultAudioInput(to, &x)
        return create(x)
    }

    func defaultAudioVideoInput(_ to: String, _ preview: AVCaptureVideoPreviewLayer) -> IOSessionProtocol? {
        var x = [IOSessionProtocol]()
        _defaultVideoInput(to, preview, &x)
        _defaultAudioInput(to, &x)
        return create(x)
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func startAudioOutput(_ session: IOSessionProtocol?) throws {
        activeAudioOutput?.stop()
        activeAudioOutput = nil
        try session?.start()
        activeAudioOutput = session
    }
    
    func defaultNetworkInputVideo(_ output: VideoOutputProtocol) -> IODataProtocol {
        let result =
            IODataDispatcher(
                avOutputQueue,
                NetworkH264Deserializer(
                    VideoDecoderH264(
                        output)))
        
        return result
    }

    func defaultNetworkOutputAudio(_ format: AudioFormat, session: inout IOSessionProtocol?) -> IODataProtocol {
        let output =
            AudioOutput(format, AV.defaultAudioFormat, AV.defaultAudioInterval)
        
        let result =
            NetworkAACDeserializer(
                output)
        
        session = output
        
        return result
    }
    
    func setupDefaultNetworkInputAudio(_ platformSession: IOSessionProtocol?) {
        Backend.shared.audioSessionStart = { (_, format: AudioFormat) throws in
            var session: IOSessionProtocol? = nil
            let result = AV.shared.defaultNetworkOutputAudio(format, session: &session)
            
            if platformSession != nil && session != nil {
                let shared = session!
                let broadcast = create([platformSession!, shared])
                
                session = broadcast
            }
            
            if session == nil {
                session = platformSession
            }
            
            try self.startAudioOutput(session)
            
            return result
        }
        
        Backend.shared.audioSessionStop = { (_) in
            try! self.startAudioOutput(nil)
        }
    }
}
