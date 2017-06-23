
import UIKit

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutgoingCallProposalUI : NetworkOutgoingCallProposal {
    
    private let ui: DetailViewController?
    
    init(_ info: NetworkCallInfo, _ ui: DetailViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
    }
    
    override func stop() {
        super.stop()
    }
    
    override func accept(_ info: NetworkCallInfo) {
        super.accept(info)
    }
    
    override func decline() {
        super.decline()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallProposalUI : NetworkIncomingCallProposal {
    
    private let ui: DetailViewController?
    
    init(_ info: NetworkCallInfo, _ ui: DetailViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
        accept(info)
    }
    
    override func stop() {
        super.stop()
    }
    
    override func accept(_ info: NetworkCallInfo) {
        super.accept(info)
    }
    
    override func decline() {
        super.decline()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fileprivate func startCall(_ to: String, _ info: NetworkCallInfo, _ ui: DetailViewController?) {
    
    if info.audio && info.video {
//        AV.shared.captureAV(to, preview: ui.videoViewController.preview.captureLayer)
    }
    
    else if info.audio {
//        AV.shared.captureAudio(to)
    }
    
    else if info.video {
//        AV.shared.captureVideo(to, preview: ui.videoViewController.preview.captureLayer)
    }
}

fileprivate func stopCall(_ ui: DetailViewController?) {
    
    AV.shared.stopAllOutput()
}

class NetworkOutgoingCallUI : NetworkOutgoingCall {
    
    private let ui: DetailViewController?
    
    init(_ info: NetworkCallInfo, _ ui: DetailViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
    }
    
    override func stop() {
        super.stop()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallUI : NetworkIncomingCall {
    
    private let ui: DetailViewController?
    
    init(_ info: NetworkCallInfo, _ ui: DetailViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        try super.start()
        
        Model.shared.watching = info.from
        
        if info.from != info.to {
            startCall(info.from, info, ui)
        }
    }
    
    override func stop() {
        super.stop()
        stopCall(ui)
    }
}
