
import Cocoa

func discardCallProposal(_ ui: ConversationViewController) {
    dispatch_sync_on_main {
        ui.showMessages()
        ui.enableCall()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutgoingCallProposalUI : NetworkOutgoingCallProposal {
    
    private let ui: ConversationViewController
    
    init(_ info: NetworkCallProposalInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info, ui.outgoingCallViewController)
    }
    
    override func start() throws {
        try super.start()
        
        dispatch_sync_on_main {
            ui.showOutgoingCall()
        }
    }
    
    override func stop() {
        super.stop()
        discardCallProposal(ui)
    }
    
    override func accept(_ info: NetworkCallProposalInfo) {
        super.accept(info)
    }
    
    override func decline() {
        super.decline()
        discardCallProposal(ui)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallProposalUI : NetworkIncomingCallProposal {
    
    private let ui: ConversationViewController
    
    init(_ info: NetworkCallProposalInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info, ui.incomingCallViewController)
    }
    
    override func start() throws {
        try super.start()
        dispatch_sync_on_main { ui.showIncomingCall(info.from) }
    }
    
    override func stop() {
        super.stop()
        discardCallProposal(ui)
    }
    
    override func accept(_ info: NetworkCallProposalInfo) {
        super.accept(info)
        
        dispatch_sync_on_main {
            ui.showVideo()
        }
    }
    
    override func decline() {
        super.decline()
        discardCallProposal(ui)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Call
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fileprivate func videoCapture(_ id: IOID,
                              _ ui: ConversationViewController,
                              _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
    let video = AV.shared.defaultNetworkVideoInput(id,
                                                   ui.videoViewController.preview.captureLayer,
                                                   &info)
    
    return VideoSessionAsyncDispatcher(AV.shared.videoCaptureQueue, video!)
}

fileprivate func videoOutput(_ info: NetworkVideoSessionInfo,
                             _ ui: ConversationViewController,
                             _ session: inout IOSessionProtocol?) -> IODataProtocol? {
    return AV.shared.defaultNetworkVideoOutput(info.id,
                                               ui.videoViewController.network.sampleLayer,
                                               &session)
}

fileprivate func startCall(_ to: String, _ info: NetworkCallInfo, _ ui: ConversationViewController) {
    
    dispatch_sync_on_main {
        if info.proposal.video {
            ui.btnVideoCallStop.isHidden = false
        }
            
        else if info.proposal.audio {
            ui.btnAudioCallStop.isHidden = false
        }
        
        ui.showVideo()
    }
}

fileprivate func stopCall(_ ui: ConversationViewController) {
    
    dispatch_sync_on_main {
        ui.showMessages()
        ui.enableCall()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutgoingCallUI : NetworkOutgoingCall {
    
    private let ui: ConversationViewController

    init(_ info: NetworkCallInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
        startCall(info.to, info, ui)
    }
    
    override func stop() {
        super.stop()
        stopCall(ui)
    }
    
    override func videoCapture(_ id: IOID, _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
        return Chat.videoCapture(id, ui, &info)
    }
    
    override func videoOutput(_ info: NetworkVideoSessionInfo,
                              _ session: inout IOSessionProtocol?) throws -> IODataProtocol? {
        return Chat.videoOutput(info, ui, &session)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallUI : NetworkIncomingCall {
    
    private let ui: ConversationViewController
    
    init(_ info: NetworkCallInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info)
    }

    override func start() throws {
        try super.start()
        
        if info.from != info.to {
            startCall(info.from, info, ui)
        }
    }
    
    override func stop() {
        super.stop()
        stopCall(ui)
    }
    
    override func videoCapture(_ id: IOID, _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
        return Chat.videoCapture(id, ui, &info)
    }
    
    override func videoOutput(_ info: NetworkVideoSessionInfo,
                              _ session: inout IOSessionProtocol?) throws -> IODataProtocol? {
        return Chat.videoOutput(info, ui, &session)
    }
}
