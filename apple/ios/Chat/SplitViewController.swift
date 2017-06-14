import UIKit

class SplitViewController : UISplitViewController {

    private static let usernameKey = "username"

    private static var shared: SplitViewController?

    override func viewDidLoad() {
        SplitViewController.shared = self
        self.connect()
    }

    private func connect() {
        EventBus.addListener(about: .connected, didReceive: { notification in
            if let credential = Backend.shared.credential {
                Backend.shared.login(username: credential.username, password: credential.password)
            } else {
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

        Backend.shared.connect()
    }
}
