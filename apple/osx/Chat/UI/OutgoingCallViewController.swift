
import Cocoa

class OutgoingCallViewController: NSViewController {
   
    var info: NetworkCallInfo?

    private func call(_ to: String, _ audio: Bool, _ video: Bool) {
        let info = NetworkCallInfo(UUID().uuidString,
                                   Model.shared.username!,
                                   to,
                                   audio,
                                   video)
        self.info = info
        
        dispatch_async_network_call {
            NetworkCallProposalController.outgoing?.start(info)
        }
    }
    
    func callAudio(_ to: String) {
        call(to, true, false)
    }

    func callVideo(_ to: String) {
        call(to, true, true)
    }

    @IBAction func btnCancelPressed(_ sender: Any) {
        let info = self.info!
      
        dispatch_async_network_call {
            NetworkCallProposalController.outgoing?.stop(info.id)
        }
    }
}
