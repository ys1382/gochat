import UIKit

class SplitViewController : UISplitViewController {

    private static let usernameKey = "username"

    private static var shared: SplitViewController?

    private func login(username: String) {
        Backend.shared.connect(withUsername: username)
    }

    override func viewDidAppear(_ animated: Bool) {
        SplitViewController.shared = self
        if let username = UserDefaults.standard.string(forKey: SplitViewController.usernameKey) {
            self.login(username: username)
        } else {
            askName()
        }
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

    private func askName() {
        SplitViewController.askString(title:"Hello world", cancellable: false) { username in
            UserDefaults.standard.set(username, forKey:SplitViewController.usernameKey)
            self.login(username: username)
        }
    }
}
