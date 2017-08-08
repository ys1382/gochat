import Cocoa

@NSApplicationMain
class AppDelegate: Application, NSApplicationDelegate {

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
    
    static func ask(title: String, subtitle: String, cancelable: Bool, done:(String?)->Void) {
        let alert = NSAlert()
        
        alert.addButton(withTitle: "OK")
        if cancelable {
            alert.addButton(withTitle: "Cancel")
        }
        
        alert.messageText = title
        alert.informativeText = subtitle
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        
        let ok = alert.runModal() == NSAlertFirstButtonReturn
        done(ok ? textField.stringValue : nil)
    }
    
}
