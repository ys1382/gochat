
import Cocoa

class IncomingCallViewController : NSViewController {
    @IBOutlet weak var lblTitle: NSTextField!
    
    private var titleText = ""
    private var info: NetworkCallInfo?
    
    override func viewDidLoad() {
        titleText = lblTitle.stringValue
    }
    
    func showCall(_ info: NetworkCallInfo) {
        self.info = info
        self.lblTitle.stringValue = titleText + info.from
    }
    
    @IBAction func btnAcceptPressed(_ sender: Any) {
        let info = self.info!
        
        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.accept(info)
        }
    }

    @IBAction func btnDeclinePressed(_ sender: Any) {
        let info = self.info!

        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.decline(info.id)
        }
    }
}
