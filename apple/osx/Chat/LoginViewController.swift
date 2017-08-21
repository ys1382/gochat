import Cocoa

class LoginViewController : NSWindowController {

    @IBOutlet var loginWindow: NSWindow!
    private static var shared: LoginViewController?

    @IBOutlet weak var password: NSTextField!
    @IBOutlet weak var username: NSTextField!

    @IBAction func didClickLogin(_ sender: Any) {
        loginWindow?.close()
        Auth.shared.login(username: username.stringValue, password: password.stringValue)
    }

    @IBAction func didClickRegister(_ sender: Any) {
        loginWindow?.close()
        Auth.shared.register(username: username.stringValue, password: password.stringValue)
    }

    static func popup() {
        // Xcode8 compiler
        // shared = LoginViewController(windowNibName: NSNib.Name(rawValue: "Login"))
        shared = LoginViewController(windowNibName: "Login")
        shared?.showWindow(nil)
        shared?.loginWindow.makeKey()
    }
}
