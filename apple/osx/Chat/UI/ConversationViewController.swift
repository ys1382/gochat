
import Cocoa

class ConversationViewController : NSViewController {
    
    @IBOutlet weak var textContainerView: NSView!
    @IBOutlet weak var videoContainerView: NSView!
    @IBOutlet weak var outgoingCallContainerView: NSView!
    @IBOutlet weak var incomingCallContainerView: NSView!
    
    @IBOutlet weak var btnAudioCall: NSButton!
    @IBOutlet weak var btnVideoCall: NSButton!
    @IBOutlet weak var btnAudioCallStop: NSButton!
    @IBOutlet weak var btnVideoCallStop: NSButton!

    @IBOutlet weak var viewToolbar: NSView!

    private var watching: String?
    
    var textViewController: TextViewController! {
        get {
            return childViewControllers[0] as! TextViewController
        }
    }
    
    var videoViewController: VideoViewController! {
        get {
            return childViewControllers[1] as! VideoViewController
        }
    }

    var outgoingCallViewController: OutgoingCallViewController! {
        get {
            return childViewControllers[2] as! OutgoingCallViewController
        }
    }

    var incomingCallViewController: IncomingCallViewController! {
        get {
            return childViewControllers[3] as! IncomingCallViewController
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NetworkCallProposalController.incoming = NetworkCallProposalController { (info: NetworkCallInfo) in
            return NetworkIncomingCallProposalUI(info, self)
        }

        NetworkCallProposalController.outgoing = NetworkCallProposalController { (info: NetworkCallInfo) in
            return NetworkOutgoingCallProposalUI(info, self)
        }

        NetworkCallController.incoming = NetworkCallController { (info: NetworkCallInfo) in
            return NetworkIncomingCallUI(info, self)
        }

        NetworkCallController.outgoing = NetworkCallController { (info: NetworkCallInfo) in
            return NetworkOutgoingCallUI(info, self)
        }

        Backend.shared.videoSessionStart = { (id: IOID, format: VideoFormat) throws in
            try self.videoViewController?.videoSessionStart?(id, format)
        }
        
        Backend.shared.videoSessionStop = { (id: IOID) in
            self.videoViewController?.videoSessionStop?(id)
        }
    }
    
    @IBAction func btnAudioCallPressed(_ sender: Any) {
        _onCallStarted()
        outgoingCallViewController.callAudio(watching!)
    }
    
    @IBAction func btnVideoCallPressed(_ sender: Any) {
        _onCallStarted()
        outgoingCallViewController.callVideo(watching!)
    }

    @IBAction func btnVideoCallStop(_ sender: Any) {
        _onCallStoppped()
    }
    
    @IBAction func btnAudioCallStop(_ sender: Any) {
        _onCallStoppped()
    }

    private func _onCallStarted() {
        outgoingCallContainerView.isHidden = false
        btnAudioCall.isEnabled = false
        btnVideoCall.isEnabled = false
    }

    private func _onCallStoppped() {
        _enableCall()
        
        dispatch_async_network_call {
            NetworkCallController.incoming?.stop()
            NetworkCallController.outgoing?.stop()
        }
    }

    private func _enableCall() {
        btnAudioCallStop.isHidden = true
        btnVideoCallStop.isHidden = true
        btnAudioCall.isEnabled = true
        btnVideoCall.isEnabled = true
    }
    
    func update(_ watching: String?) {
        self.watching = watching
        
        textViewController?.update(watching)
        textContainerView.isHidden = watching == nil
        
        btnAudioCall.isHidden = watching == nil
        btnVideoCall.isHidden = watching == nil
    }
    
    func _hideAll() {
        outgoingCallContainerView.isHidden = true
        incomingCallContainerView.isHidden = true
        textContainerView.isHidden = true
        videoContainerView.isHidden = true
        viewToolbar.isHidden = true
    }
    
    func showOutgoingCall() {
        _hideAll()
        outgoingCallContainerView.isHidden = false
    }

    func showIncomingCall() {
        _hideAll()
        incomingCallContainerView.isHidden = false
    }

    func showMessages() {
        _hideAll()
        textContainerView.isHidden = false
        viewToolbar.isHidden = false
    }

    func showVideo() {
        _hideAll()
        videoContainerView.isHidden = false
        viewToolbar.isHidden = false
    }
    
    func enableCall() {
        _enableCall()
    }
}
