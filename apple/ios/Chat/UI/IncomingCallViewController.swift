
import UIKit

class IncomingCallViewController : UIViewController, NetworkCallProposalReceiverProtocol {
    
    @IBOutlet weak var lblTitle: UILabel!
    var lblTitleText: String?
   
    var callInfo: NetworkCallProposalInfo? {
        didSet {
            if callInfo != nil {
                _ = view
                lblTitle.text = lblTitleText! + callInfo!.from
            }
            else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func btnAcceptAction(_ sender: Any) {
        let info = self.callInfo!
        
        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.accept(info)
        }
    }

    @IBAction func btnDeclineAction(_ sender: Any) {
        let info = self.callInfo!

        dispatch_async_network_call {
            NetworkCallProposalController.incoming?.decline(info)
        }
    }
    
    override func viewDidLoad() {
        lblTitleText = lblTitle.text
    }
}
