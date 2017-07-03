
import UIKit

class OutgoingCallViewController : UIViewController, NetworkCallProposalReceiverProtocol {

    @IBOutlet weak var lblTitle: UILabel!
    var lblTitleText: String?

    var callInfo: NetworkCallProposalInfo? {
        didSet {
            if callInfo != nil {
                _ = view
                lblTitle.text = lblTitleText! + callInfo!.to
            }
            else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBAction func btnCancelAction(_ sender: Any) {
        let info = self.callInfo!
        
        dispatch_async_network_call {
            NetworkCallProposalController.outgoing?.stop(info)
        }
    }
    
    override func viewDidLoad() {
        lblTitleText = lblTitle.text
    }
}
