import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        EventBus.addListener(about: .connected, didReceive: { notification in
            if !Auth.shared.login() {
                LoginViewController.popup()
            }
        })

        EventBus.addListener(about: .disconnected, didReceive: { notification in
            let alert = NSAlert()
            alert.messageText = "Disconnected"
            alert.informativeText = "Not connected to server"
            alert.addButton(withTitle: "Ok")
            alert.runModal()
        })

        WireBackend.shared.connect()
    }
}
