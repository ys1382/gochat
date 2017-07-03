
import UIKit
import AVFoundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutgoingCallProposalUI : NetworkOutgoingCallProposal {
    
    private let ui: SplitViewController
    private let vc: OutgoingCallViewController

    init(_ info: NetworkCallProposalInfo, _ ui: SplitViewController, _ vc: OutgoingCallViewController) {
        self.ui = ui
        self.vc = vc
        super.init(info, vc)
    }
    
    override func start() throws {
        try super.start()
        dispatch_sync_on_main { ui.present(vc, animated: true) }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallProposalUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallProposalUI : NetworkIncomingCallProposal {
    
    private let ui: SplitViewController
    private let vc: IncomingCallViewController
    
    init(_ info: NetworkCallProposalInfo, _ ui: SplitViewController, _ vc: IncomingCallViewController) {
        self.ui = ui
        self.vc = vc
        super.init(info, vc)
    }
    
    override func start() throws {
        try super.start()
        dispatch_sync_on_main { ui.presentExplicitly(vc, animated: true) }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Call
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fileprivate func videoCapture(_ id: IOID,
                              _ context: IOInputContext,
                              _ vc: VideoViewController,
                              _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
    var videoSession: AVCaptureSession.Accessor? = nil
    let orientation = AVCaptureVideoOrientation.Create(UIApplication.shared.statusBarOrientation)
    let rotated = orientation != nil ? orientation!.isPortrait : false
    var video = AV.shared.defaultNetworkVideoInput(id, context, rotated, &info, &videoSession)
    
    if video != nil && videoSession != nil {
        video = ChatVideoCaptureSession(videoConnection(videoSession)!,
                                        AV.shared.defaultVideoOutputFormat!,
                                        AVCaptureVideoOrientation.landscapeRight,
                                        video)
        
        video = ChatVideoPreviewSession(vc.previewView.captureLayer,
                                        video)
        
        video = VideoPreview(vc.previewView.captureLayer,
                             videoSession!,
                             video)
        
        video = VideoSessionAsyncDispatcher(AV.shared.videoCaptureQueue, video!)
    }
    
    return video
}

fileprivate func videoOutput(_ info: NetworkVideoSessionInfo,
                             _ vc: VideoViewController,
                             _ context: IOOutputContext) -> IOOutputContext? {
    return AV.shared.defaultNetworkVideoOutput(info.id,
                                               context,
                                               VideoOutput(vc.networkView.sampleLayer))
}

fileprivate func startCall(_ to: String,
                           _ info: NetworkCallInfo,
                           _ ui: SplitViewController?,
                           _ details: inout DetailViewController?,
                           _ video: inout VideoViewController?) {
    
    Model.shared.watching = info.proposal.from

    dispatch_sync_on_main {
        Model.shared.watching = to
        
        if info.proposal.video {
            video = ui?.showVideoIfNeeded()
            _ = video!.view
            video!.callInfo = info
        }
        
        else if info.proposal.audio {
            details = ui?.showDetailsIfNeeded()
            _ = details!.view
            details!.callInfo = info
        }
    }
}

fileprivate func stopCall(_ ui: SplitViewController?, _ details: DetailViewController?, _ video: VideoViewController?) {
    
    dispatch_sync_on_main {
        if video != nil {
            video?.navigationController?.popViewController(animated: true)
            video?.callInfo = nil
        }
        
        if details != nil {
            details?.callInfo = nil
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutgoingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutgoingCallUI : NetworkOutgoingCall {
    
    private let ui: SplitViewController?
    private var details: DetailViewController?
    private var video: VideoViewController?
    
    init(_ info: NetworkCallInfo, _ ui: SplitViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        startCall(info.to, info, ui, &details, &video)
        try super.start()
    }

    override func stop() {
        super.stop()
        stopCall(ui, details, video)
    }

    override func videoCapture(_ id: IOID, _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
        return Chat.videoCapture(id, inputContext!, video!, &info)
    }
    
    override func videoOutput(_ info: NetworkVideoSessionInfo,
                              _ context: IOOutputContext) throws -> IOOutputContext? {
        return Chat.videoOutput(info, video!, context)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkIncomingCallUI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkIncomingCallUI : NetworkIncomingCall {
    
    private let ui: SplitViewController?
    private var details: DetailViewController?
    private var video: VideoViewController?

    init(_ info: NetworkCallInfo, _ ui: SplitViewController?) {
        self.ui = ui
        super.init(info)
    }
    
    override func start() throws {
        startCall(info.from, info, ui, &details, &video)
        try super.start()
    }
    
    override func stop() {
        super.stop()
        stopCall(ui, details, video)
    }
    
    override func videoCapture(_ id: IOID, _ info: inout NetworkVideoSessionInfo?) -> IOSessionProtocol? {
        return Chat.videoCapture(id, inputContext!, video!, &info)
    }
    
    override func videoOutput(_ info: NetworkVideoSessionInfo,
                              _ context: IOOutputContext) throws -> IOOutputContext? {
        return Chat.videoOutput(info, video!, context)
    }
}
