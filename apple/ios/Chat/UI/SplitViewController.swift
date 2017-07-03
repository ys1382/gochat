import UIKit

class SplitViewController : UISplitViewController {

    private static let usernameKey = "username"

    private static var shared: SplitViewController?

    private var navController: UINavigationController? {
        get {
            var result = viewControllers.last as? UINavigationController
            
            if (result?.topViewController is UINavigationController) {
                result = result!.topViewController as? UINavigationController
            }
            
            return result
        }
    }

    private var detailViewController: DetailViewController? {
        get {
            guard let navController = self.navController else { return nil }
            
            for i in navController.viewControllers {
                if i is DetailViewController {
                    return i as? DetailViewController
                }
            }
            
            return nil
        }
    }

    private var detailViewControllerOnTop: Bool {
        return self.navController?.topViewController == self.detailViewController
    }

    override func viewDidLoad() {
        // setup call
        
        NetworkCallProposalController.incoming = NetworkCallProposalController { (info: NetworkCallProposalInfo) in
            let vc:IncomingCallViewController  = instantiateViewController(self.storyboard!)
            return NetworkIncomingCallProposalUI(info, self, vc)
        }
        
        NetworkCallProposalController.outgoing = NetworkCallProposalController { (info: NetworkCallProposalInfo) in
            let vc: OutgoingCallViewController = instantiateViewController(self.storyboard!)
            return NetworkOutgoingCallProposalUI(info, self, vc)
        }
        
        NetworkCallController.incoming = NetworkCallController { (info: NetworkCallInfo) in
            return NetworkIncomingCallUI(info, self)
        }
        
        NetworkCallController.outgoing = NetworkCallController { (info: NetworkCallInfo) in
            return NetworkOutgoingCallUI(info, self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        SplitViewController.shared = self
        if let username = UserDefaults.standard.string(forKey: SplitViewController.usernameKey) {
            login(username: username)
        } else {
            askName()
        }
    }
    
    func showDetailsIfNeeded() -> DetailViewController {
        if detailViewController == nil {
            performSegue(withIdentifier: "showDetail" , sender:self)
        }
        
        return detailViewController!
    }
    
    func showVideoIfNeeded() -> VideoViewController {
        if self.navController?.topViewController is VideoViewController {
            return self.navController?.topViewController as! VideoViewController
        }
        
        self.showDetailsIfNeeded().navigationController!.performSegue(withIdentifier: "pushVideo", sender: self)
        return self.detailViewController?.navigationController?.topViewController as! VideoViewController
    }
    
    func popToDetailsIfNeededAnimated() -> DetailViewController? {
        guard let detailViewController = self.detailViewController else { return nil }
        
        self.navigationController?.popToViewController(detailViewController, animated: true)

        return detailViewController
    }
    
    static func askString(title: String, cancellable: Bool, done:@escaping (String)->Void) {
        let alertController = UIAlertController(title: nil,
                                                message: title,
                                                preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
            if let text = alertController.textFields?[0].text {
                done(text)
            }
        }
        alertController.addAction(okAction)

        if cancellable {
            let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel)
            alertController.addAction(cancelAction)
        }

        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "New contact name"
        }
        SplitViewController.shared?.present(alertController, animated: true, completion: nil)
    }

    private func login(username: String) {
        if Model.shared.username == nil {
            Backend.shared.connect(withUsername: username)
        }
    }

    private func askName() {
        SplitViewController.askString(title:"Hello world", cancellable: false) { username in
            UserDefaults.standard.set(username, forKey:SplitViewController.usernameKey)
            self.login(username: username)
        }
    }
}
