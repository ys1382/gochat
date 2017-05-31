
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Assertions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func assert_video_capture_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.videoCaptureQueue))
}

func assert_audio_capture_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.audioCaptureQueue))
}

func assert_video_output_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.videoOutputQueue))
}

func assert_audio_output_queue() {
    assert(ChatDispatchQueue.OnQueue(AV.shared.audioOutputQueue))
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AV
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class AV {
    
    static let shared = AV()
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IO
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    let videoCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.VideoCaptureQueue")
    let audioCaptureQueue = ChatDispatchQueue.CreateCheckable("chat.AudioCaptureQueue")

    let videoOutputQueue = ChatDispatchQueue.CreateCheckable("chat.AVOutputQueue")
    var audioOutputQueue: DispatchQueue {
        get {
            return videoOutputQueue
        }
    }

    private(set) var activeInput: IOSessionProtocol?
    private(set) var activeOutput: IOSessionProtocol?
    
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

        let videoInput =
            VideoInput(
                device,
                preview,
                AV.shared.videoCaptureQueue,
                VideoEncoderH264(
                    sessionEncoder,
                    NetworkH264Serializer(
                        NetworkOutputVideo(to))))
        
        x.append(IOSessionBroadcast([sessionEncoder, videoInput, sessionNetwork]))
    }

    private func _defaultAudioInput(_ to: String, _ x: inout [IOSessionProtocol]) {
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

    func defaultNetworkOutputVideo(_ output: VideoOutputProtocol) -> IODataProtocol {
        let result =
            IODataDispatcher(
                videoOutputQueue,
                NetworkH264Deserializer(
                    VideoDecoderH264(
                        output)))
        
        return result
    }
}
