import UIKit

class SplitViewController : UISplitViewController {

    private static let usernameKey = "username"

    private static var shared: SplitViewController?

    override func viewDidLoad() {
        SplitViewController.shared = self
        connect()
    }

    private func connect() {
        EventBus.addListener(about: .connected, didReceive: { notification in
            if !Auth.shared.login() {
                self.performSegue(withIdentifier: "login", sender: nil)
            }
        })

        EventBus.addListener(about: .disconnected, didReceive: { notification in
            let alertController = UIAlertController(title: "Disconnected",
                                                    message: "Not connected to server",
                                                    preferredStyle: UIAlertControllerStyle.alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { (action) in }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        })

        WireBackend.shared.connect()
    }
}
