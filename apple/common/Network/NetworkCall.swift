
import Foundation

extension DispatchQueue {
    static let networkCall = DispatchQueue.CreateCheckable("chat.NetworkCallQueue")
}

func assert_network_call_queue() {
    assert(DispatchQueue.OnQueue(DispatchQueue.networkCall))
}

func dispatch_async_network_call(_ block: @escaping FuncVV) {
    DispatchQueue.networkCall.async { block() }
}

class NetworkCallSessionController<T, I> {
    
    fileprivate func create(_ info: I) -> T? {
        assert(false)
        return nil
    }
    
    fileprivate func id(_ info: I) -> String {
        assert(false)
        return ""
    }

    fileprivate func call(_ info: I) -> T? {
        assert(false)
        return nil
    }
    
    func start(_ info: I) {
        assert_network_call_queue()
    }
    
    func stop(_ info: I) {
        assert_network_call_queue()
    }
}

class NetworkSingleCallSessionController<T: SessionProtocol, I> : NetworkCallSessionController<T, I> {
    
    var call: T?
    var callInfo: I?
    
    override func start(_ info: I) {
        super.start(info)
        
        stop()
        call = create(info)
        callInfo = info
        do { try call?.start() } catch { logNetworkError(error) }
    }
    
    override func stop(_ info: I) {
        assert_network_call_queue()
        
        guard let callInfo = self.callInfo else { return }
        guard id(callInfo) == id(info) else { return }
        
        call?.stop()
        
        self.call = nil
        self.callInfo = nil
    }
    
    func stop() {
        guard callInfo != nil else { return }
        stop(callInfo!)
    }
    
    fileprivate override func call(_ info: I) -> T? {
        guard let callInfo = self.callInfo else { return nil }
        guard id(callInfo) == id(info) else { return nil }
        
        return call
    }
}

class NetworkMultiCallSessionController<T: SessionProtocol, I> : NetworkCallSessionController<T, I> {
    
    private var calls = [String: T]()

    override func start(_ info: I) {
        super.start(info)
        
        let call = create(info)
        calls[id(info)] = call
        do { try call!.start() } catch { logNetworkError(error) }
    }
    
    override func stop(_ info: I) {
        assert_network_call_queue()

        calls[id(info)]?.stop()
        calls.removeValue(forKey: id(info))
    }
    
    fileprivate override func call(_ info: I) -> T? {
        return calls[id(info)]
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Call
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct NetworkCallInfo {
    
    let proposal: NetworkCallProposalInfo
    let audioSession: NetworkAudioSessionInfo?
    let videoSession: NetworkVideoSessionInfo?

    init(_ proposal: NetworkCallProposalInfo,
         _ audioSession: NetworkAudioSessionInfo?,
         _ videoSession: NetworkVideoSessionInfo?) {
        self.proposal = proposal
        self.audioSession = audioSession
        self.videoSession = videoSession
    }

    init(_ proposal: NetworkCallProposalInfo, audioSession: NetworkAudioSessionInfo) {
        self.init(proposal, audioSession, nil)
    }

    init(_ proposal: NetworkCallProposalInfo, videoSession: NetworkVideoSessionInfo) {
        self.init(proposal, nil, videoSession)
    }
    
    init(_ proposal: NetworkCallProposalInfo) {
        self.init(proposal, nil, nil)
    }
    
    var id: String { get { return proposal.id } }
    var from: String { get { return proposal.from } }
    var to: String { get { return proposal.to } }
}

protocol NetworkCallProtocol : SessionProtocol {
    
}

protocol NetworkCallReceiverProtocol {
    var callInfo: NetworkCallInfo? { get set }
}

typealias NetworkCallFactory = (NetworkCallInfo) -> NetworkCallProtocol

class NetworkCall : NetworkCallProtocol {
    
    let info: NetworkCallInfo
    private var ui: NetworkCallReceiverProtocol?
    
    private(set) var inputContext: IOInputContext?
    private var audioInputSession: IOSessionProtocol?
    private var videoInputSession: IOSessionProtocol?

    private(set) var outputContext: IOOutputContext?
    private var audioOutputContext: IOOutputContext?
    private var videoOutputContext: IOOutputContext?
    
    init(_ info: NetworkCallInfo) {
        self.info = info
    }

    convenience init(_ info: NetworkCallInfo, _ ui: NetworkCallReceiverProtocol) {
        self.init(info)
        self.ui = ui
    }

    func counterpart() -> String {
        return info.from
    }
    
    func start() throws {
        assert_network_call_queue()
        
        outputContext = IOOutputContext()
        inputContext = IOInputContext(NetworkCallQuality(counterpart(), info))
        
        dispatch_sync_on_main { ui?.callInfo = info }
        _ = try startCapture(info.from, info.to)
    }
    
    func stop() {
        assert_network_call_queue()
        dispatch_sync_on_main { ui?.callInfo = nil }
        
        audioInputSession?.stop()
        AV.shared.videoCaptureQueue.sync { videoInputSession?.stop() }
        AV.shared.avOutputQueue.sync { audioOutputContext?.session?.stop() }
        AV.shared.avOutputQueue.sync { videoOutputContext?.session?.stop() }
    }
    
    func audioOutput(_ info: NetworkAudioSessionInfo, _ context: IOOutputContext) throws -> IOOutputContext? {
        return AV.shared.defaultNetworkAudioOutput(info.id, try info.format!(), context)
    }

    func videoOutput(_ info: NetworkVideoSessionInfo, _ context: IOOutputContext) throws -> IOOutputContext? {
        return nil
    }

    fileprivate func startOutput(_ info: NetworkAudioSessionInfo) throws -> IODataProtocol? {
        audioOutputContext = try audioOutput(info, outputContext!)
        try AV.shared.avOutputQueue.sync { try audioOutputContext?.session?.start() }
        return audioOutputContext?.data
    }

    fileprivate func startOutput(_ info: NetworkVideoSessionInfo) throws -> IODataProtocol? {
        videoOutputContext = try videoOutput(info, outputContext!)
        try AV.shared.avOutputQueue.sync { try videoOutputContext?.session?.start() }
        return videoOutputContext?.data
    }

    func audioCapture(_ id: IOID, _ info: inout NetworkAudioSessionInfo?) -> IOSessionProtocol? {
        return AV.shared.defaultNetworkAudioInput(id, inputContext!, &info)
    }

    func videoCapture(_ id: IOID, _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
        return nil
    }

    fileprivate func startCapture(_ from: String, _ to: String) throws -> NetworkCallInfo {
        let audioID = IOID(from, to)
        let videoID = audioID.groupNew()
        
        let audio = info.proposal.audio ? try startAudioCapture(audioID) : nil
        let video = info.proposal.video ? try startVideoCapture(videoID) : nil
        
        return NetworkCallInfo(info.proposal, audio, video)
    }

    fileprivate func startAudioCapture(_ id: IOID) throws -> NetworkAudioSessionInfo? {
        var info: NetworkAudioSessionInfo?
        
        audioInputSession = audioCapture(id, &info)
        try audioInputSession?.start()
        
        return info
    }
    
    fileprivate func startVideoCapture(_ id: IOID) throws -> NetworkVideoSessionInfo? {
        var info: NetworkVideoSessionInfo?
        
        videoInputSession = videoCapture(id, &info)
        try videoInputSession?.start()
        
        return info
    }
}

class NetworkOutgoingCall : NetworkCall {
    
    override fileprivate func startCapture(_ from: String, _ to: String) throws -> NetworkCallInfo {
        let info = try super.startCapture(from, to)
        VoipBackend.sendOutgoingCallStart(info.to, info)
        return info
    }
    
    override func stop() {
        super.stop()
        //Backend.shared.sendCallStop(info.to, info)
        VoipBackend.sendCallStop(info.to, info)
    }
}

class NetworkIncomingCall : NetworkCall {

    override func counterpart() -> String {
        return info.to
    }

    override fileprivate func startCapture(_ from: String, _ to: String) throws -> NetworkCallInfo {
        var info = self.info
        
        if info.from != info.to {
            info = try super.startCapture(to, from)
            //Backend.shared.sendIncomingCallStart(info.from, info)
            VoipBackend.sendIncomingCallStart(info.from, info)
        }
        return info
    }

    override func stop() {
        super.stop()
        //Backend.shared.sendCallStop(info.from, info)
        VoipBackend.sendCallStop(info.from, info)
    }
}

class NetworkCallController : NetworkSingleCallSessionController<NetworkCall, NetworkCallInfo> {
    
    static var incoming: NetworkCallController?
    static var outgoing: NetworkCallController?
    
    private let factory: NetworkCallFactory
    
    init(_ factory: @escaping NetworkCallFactory) {
        self.factory = factory
    }
    
    override func id(_ info: NetworkCallInfo) -> String {
        return info.id
    }
    
    override func create(_ info: NetworkCallInfo) -> NetworkCall? {
        return factory(info) as? NetworkCall
    }
    
    func startOutput(_ call: NetworkCallInfo, _ audio: inout IODataProtocol?, _ video: inout IODataProtocol?) throws {
        assert_network_call_queue()
        guard self.callInfo?.id == call.id else { print("asd"); return }

        if call.audioSession != nil {
            audio = try self.call?.startOutput(call.audioSession!)
        }
        
        if call.videoSession != nil {
            video = try self.call?.startOutput(call.videoSession!)
        }
    }
    
    func changeQuality(_ info: NetworkCallInfo, _ diff: Int) {
        call(info)?.inputContext?.qos.change(diff)
    }
}

func changeCallQuality(_ call: NetworkCallInfo, _ diff: Int) {
    NetworkCallController.incoming?.changeQuality(call, diff)
    NetworkCallController.outgoing?.changeQuality(call, diff)
}

func stopCallAsync(_ info: NetworkCallInfo) {
    dispatch_async_network_call {
        NetworkCallController.incoming?.stop(info)
        NetworkCallController.outgoing?.stop(info)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Proposal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct NetworkCallProposalInfo {
    let id: String
    let from: String
    let to: String
    let audio: Bool
    let video: Bool
    
    init(_ id: String,
         _ from: String,
         _ to: String,
         _ audio: Bool,
         _ video: Bool) {
        self.id = id
        self.from = from
        self.to = to
        self.audio = audio
        self.video = video
    }
}

protocol NetworkCallProposalProtocol : SessionProtocol {
    
    func accept(_ info: NetworkCallProposalInfo)
    func decline()
}

protocol NetworkCallProposalReceiverProtocol {
    var callInfo: NetworkCallProposalInfo? { get set }
}

typealias NetworkCallProposalFactory = (NetworkCallProposalInfo) -> NetworkCallProposalProtocol

class NetworkCallProposal : NetworkCallProposalProtocol {
    
    var info: NetworkCallProposalInfo
    private var ui: NetworkCallProposalReceiverProtocol?

    init(_ info: NetworkCallProposalInfo) {
        self.info = info
    }
    
    init(_ info: NetworkCallProposalInfo, _ ui: NetworkCallProposalReceiverProtocol) {
        self.ui = ui
        self.info = info
    }
    
    func start() throws {
        assert_network_call_queue()
        dispatch_sync_on_main { ui?.callInfo = info }
    }
    
    func stop() {
        assert_network_call_queue()
        dispatch_sync_on_main { ui?.callInfo = nil }
    }
    
    func accept(_ info: NetworkCallProposalInfo) {
        assert_network_call_queue()
        self.info = info
        dispatch_sync_on_main { ui?.callInfo = nil }
    }
    
    func decline() {
        assert_network_call_queue()
        dispatch_sync_on_main { ui?.callInfo = nil }
    }
}

class NetworkOutgoingCallProposal : NetworkCallProposal {
    
    override func start() throws {
        try super.start()
        
        //Backend.shared.sendCallProposal(info.to, info)
        VoipBackend.sendCallProposal(info.to, info)
    }
    
    override func stop() {
        super.stop()
        //Backend.shared.sendCallCancel(info.to, info)
        VoipBackend.sendCallCancel(info.to, info)
    }
    
    override func accept(_ info: NetworkCallProposalInfo) {
        super.accept(info)
        NetworkCallController.outgoing?.start(NetworkCallInfo(info))
    }
}

class NetworkIncomingCallProposal : NetworkCallProposal {
    
    override func stop() {
        super.stop()
        //Backend.shared.sendCallCancel(info.from, info)
        VoipBackend.sendCallCancel(info.from, info)
    }
    
    override func accept(_ info: NetworkCallProposalInfo) {
        super.accept(info)
        //Backend.shared.sendCallAccept(info.from, info)
        VoipBackend.sendCallAccept(info.from, info)
    }
    
    override func decline() {
        super.decline()
        //Backend.shared.sendCallDecline(info.from, info)
        VoipBackend.sendCallDecline(info.from, info)
    }
}

class NetworkCallProposalController : NetworkSingleCallSessionController<NetworkCallProposal, NetworkCallProposalInfo> {
    
    static var incoming: NetworkCallProposalController?
    static var outgoing: NetworkCallProposalController?
    
    private let factory: NetworkCallProposalFactory
    
    init(_ factory: @escaping NetworkCallProposalFactory) {
        self.factory = factory
    }
    
    override func create(_ info: NetworkCallProposalInfo) -> NetworkCallProposal? {
        return factory(info) as? NetworkCallProposal
    }

    override func id(_ info: NetworkCallProposalInfo) -> String {
        return info.id
    }
    
    override func start(_ info: NetworkCallProposalInfo) {
        super.start(info)
        
        DispatchQueue.networkCall.asyncAfter(deadline: .now() + 10) {
            self.timeout(info)
        }
    }
    
    func accept(_ info: NetworkCallProposalInfo) {
        call?.accept(info)
        call = nil
    }
    
    func decline(_ info: NetworkCallProposalInfo) {
        call?.decline()
        call = nil
    }
    
    func timeout(_ info: NetworkCallProposalInfo) {
        stop(info)
    }
}

private func callAsync(_ to: String, _ audio: Bool, _ video: Bool) -> NetworkCallProposalInfo {
    let info = NetworkCallProposalInfo(UUID().uuidString,
                                       Auth.shared.username!,
                                       to,
                                       audio,
                                       video)
    
    dispatch_async_network_call {
        NetworkCallProposalController.outgoing?.start(info)
    }
    
    return info
}

func callAudioAsync(_ to: String) -> NetworkCallProposalInfo {
    return callAsync(to, true, false)
}

func callVideoAsync(_ to: String) -> NetworkCallProposalInfo {
    return callAsync(to, true, true)
}

