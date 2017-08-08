
import Cocoa

class OutgoingCallViewController: NSViewController, NetworkCallProposalReceiverProtocol {
   
    @IBOutlet weak var lblTitle: NSTextField!
    private var titleText = ""

    override func viewDidLoad() {
        titleText = lblTitle.stringValue
    }
    
    @IBAction func btnCancelPressed(_ sender: Any) {
        dispatch_async_network_call {
            NetworkCallProposalController.outgoing?.stop(self.callInfo!)
        }
    }
    
    var callInfo: NetworkCallProposalInfo? {
        didSet {
            guard callInfo != nil else { return }
            lblTitle.stringValue = titleText + callInfo!.to
        }
    }
}
