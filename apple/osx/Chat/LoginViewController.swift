import Cocoa

class LoginViewController : NSWindowController {

    private static var previewWindow: NSWindowController?

    @IBOutlet weak var password: NSTextField!
    @IBOutlet weak var username: NSTextField!

    @IBAction func didClickLogin(_ sender: Any) {
        Backend.login(username: username.stringValue, password: password.stringValue)
    }

    @IBAction func didClickRegister(_ sender: Any) {
        Backend.register(username: username.stringValue, password: password.stringValue)
    }

    static func popup() {
        previewWindow = NSWindowController(windowNibName: "Login")
        previewWindow?.showWindow(nil)
    }
}
