
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

struct NetworkCallInfo {
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

class NetworkCallSessionController<T> {
    
    fileprivate func create(_ info: NetworkCallInfo) -> T? {
        assert(false)
        return nil
    }
    
    func start(_ info: NetworkCallInfo) {
        assert_network_call_queue()
    }
    
    func stop(_ id: String) {
        assert_network_call_queue()
    }
}

class NetworkSingleCallSessionController<T: SessionProtocol> : NetworkCallSessionController<T> {
    
    var call: T?
    var callID: String?
    
    override func start(_ info: NetworkCallInfo) {
        super.start(info)
        
        stop()
        call = create(info)
        callID = info.id
        do { try call?.start() } catch { logNetworkError(error) }
    }
    
    override func stop(_ id: String) {
        assert_network_call_queue()
        
        guard callID == id else { return }
        
        call?.stop()
        call = nil
        callID = nil
    }
    
    func stop() {
        guard callID != nil else { return }
        stop(callID!)
    }
}

class NetworkMultiCallSessionController<T: SessionProtocol> : NetworkCallSessionController<T> {
    
    private var calls = [String: T]()

    override func start(_ info: NetworkCallInfo) {
        super.start(info)
        
        let call = create(info)
        calls[info.id] = call
        do { try call!.start() } catch { logNetworkError(error) }
    }
    
    override func stop(_ id: String) {
        assert_network_call_queue()

        calls[id]?.stop()
        calls.removeValue(forKey: id)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Call
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

protocol NetworkCallProtocol : SessionProtocol {
    
}

typealias NetworkCallFactory = (NetworkCallInfo) -> NetworkCallProtocol

class NetworkCall : NetworkCallProtocol {
    
    let info: NetworkCallInfo
    
    init(_ info: NetworkCallInfo) {
        self.info = info
    }
    
    func start() throws {
        assert_network_call_queue()
    }
    
    func stop() {
        assert_network_call_queue()
    }
    
    fileprivate func sendStart(_ to: String) {
        Backend.shared.sendCallStart(to, info)
    }
    
    fileprivate func sendStop(_ to: String) {
        Backend.shared.sendCallStop(to, info)
    }
}

class NetworkOutgoingCall : NetworkCall {
    
    override func start() throws {
        try super.start()
        sendStart(info.to)
    }
    
    override func stop() {
        super.stop()
        sendStop(info.to)
    }
}

class NetworkIncomingCall : NetworkCall {

    override func start() throws {
        try super.start()
    }
    
    override func stop() {
        super.stop()
        sendStop(info.from)
    }
}

class NetworkCallController : NetworkSingleCallSessionController<NetworkCall> {
    
    static var incoming: NetworkCallController?
    static var outgoing: NetworkCallController?
    
    private let factory: NetworkCallFactory
    
    init(_ factory: @escaping NetworkCallFactory) {
        self.factory = factory
    }
    
    override func create(_ info: NetworkCallInfo) -> NetworkCall? {
        return factory(info) as? NetworkCall
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Proposal
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

protocol NetworkCallProposalProtocol : SessionProtocol {
    
    func accept(_ info: NetworkCallInfo)
    func decline()
}

typealias NetworkCallProposalFactory = (NetworkCallInfo) -> NetworkCallProposalProtocol

class NetworkCallProposal : NetworkCallProposalProtocol {
    
    var info: NetworkCallInfo

    init(_ info: NetworkCallInfo) {
        self.info = info
    }
    
    func start() throws {
        assert_network_call_queue()
    }
    
    func stop() {
        assert_network_call_queue()
    }
    
    func accept(_ info: NetworkCallInfo) {
        assert_network_call_queue()
        self.info = info
    }
    
    func decline() {
        assert_network_call_queue()
    }
}

class NetworkOutgoingCallProposal : NetworkCallProposal {
    
    override func start() throws {
        try super.start()
        
        Backend.shared.sendCallProposal(info.to, info)
    }
    
    override func stop() {
        super.stop()
        Backend.shared.sendCallCancel(info.to, info)
    }
    
    override func accept(_ info: NetworkCallInfo) {
        super.accept(info)
        NetworkCallController.outgoing?.start(info)
    }
}

class NetworkIncomingCallProposal : NetworkCallProposal {
    
    override func stop() {
        super.stop()
        Backend.shared.sendCallCancel(info.from, info)
    }
    
    override func accept(_ info: NetworkCallInfo) {
        super.accept(info)
        Backend.shared.sendCallAccept(info.from, info)
    }
    
    override func decline() {
        super.decline()
        Backend.shared.sendCallDecline(info.from, info)
    }
}

class NetworkCallProposalController : NetworkSingleCallSessionController<NetworkCallProposal> {
    
    static var incoming: NetworkCallProposalController?
    static var outgoing: NetworkCallProposalController?
    
    private let factory: NetworkCallProposalFactory
    
    init(_ factory: @escaping NetworkCallProposalFactory) {
        self.factory = factory
    }
    
    override func create(_ info: NetworkCallInfo) -> NetworkCallProposal? {
        return factory(info) as? NetworkCallProposal
    }

    override func start(_ info: NetworkCallInfo) {
        super.start(info)
        
        DispatchQueue.networkCall.asyncAfter(deadline: .now() + 10) {
            self.timeout(info.id)
        }
    }
    
    func accept(_ info: NetworkCallInfo) {
        call?.accept(info)
        call = nil
    }
    
    func decline(_ id: String) {
        call?.decline()
        call = nil
    }
    
    func timeout(_ id: String) {
        stop(id)
    }
}

