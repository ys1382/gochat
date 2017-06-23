
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
    
    init(_ info: NetworkCallInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info)
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
    
    override func accept(_ info: NetworkCallInfo) {
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
    
    init(_ info: NetworkCallInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
        
        dispatch_sync_on_main {
            ui.incomingCallViewController.showCall(info)
            ui.showIncomingCall()
        }
    }
    
    override func stop() {
        super.stop()
        discardCallProposal(ui)
    }
    
    override func accept(_ info: NetworkCallInfo) {
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
// NetworkOutgoingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fileprivate func startCall(_ to: String, _ info: NetworkCallInfo, _ ui: ConversationViewController) {
    
    if info.audio && info.video {
        AV.shared.captureAV(to, preview: ui.videoViewController.preview.captureLayer)
    }
    
    else if info.audio {
        AV.shared.captureAudio(to)
    }

    else if info.video {
        AV.shared.captureVideo(to, preview: ui.videoViewController.preview.captureLayer)
    }
    
    dispatch_sync_on_main {
        if info.video {
            ui.btnVideoCallStop.isHidden = false
        }

        else if info.audio {
            ui.btnAudioCallStop.isHidden = false
        }
        
        ui.showVideo()
    }
}

fileprivate func stopCall(_ ui: ConversationViewController) {
    
    DispatchQueue.global().async {
        AV.shared.stopAllOutput()
    }
    
    dispatch_sync_on_main {
        ui.showMessages()
    }
}

class NetworkOutgoingCallUI : NetworkOutgoingCall {
    
    private let ui: ConversationViewController

    init(_ info: NetworkCallInfo, _ ui: ConversationViewController) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
        
        dispatch_sync_on_main {
            startCall(info.to, info, ui)
        }
    }
    
    override func stop() {
        super.stop()

        dispatch_sync_on_main {
            stopCall(ui)
        }
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
}
