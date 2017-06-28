
import Cocoa

class IncomingCallViewController : NSViewController, NetworkCallProposalReceiverProtocol {

    @IBOutlet weak var lblTitle: NSTextField!
    private var titleText = ""
    
    override func viewDidLoad() {
        titleText = lblTitle.stringValue
    }
    
    @IBAction func btnAcceptPressed(_ sender: Any) {
        let info = self.callInfo!
        
        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.accept(info)
        }
    }

    @IBAction func btnDeclinePressed(_ sender: Any) {
        let info = self.callInfo!

        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.decline(info)
        }
    }
    
    var callInfo: NetworkCallProposalInfo? {
        didSet {
            guard callInfo != nil else { return }
            self.lblTitle.stringValue = titleText + callInfo!.from
        }
    }

}
