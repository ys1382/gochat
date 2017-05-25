import Cocoa
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static var shared: AppDelegate!
    static let usernameKey = "usernamekey"

    let audioInp = TRAudioInput()
    let audioOut = TRAudioOutputBroadcast([TRAudioOutputSerializer(TRAudioOutput()), TRNetworkAudioOutput()])
    
    func login(username: String) {
        Backend.shared.connect(withUsername: username)
    }

    override init() {
        super.init()
        
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let username = UserDefaults.standard.string(forKey: AppDelegate.usernameKey) {
            self.login(username: username)
        } else {
            AppDelegate.ask(title: "Login", subtitle: "Enter your username", cancelable: false) { username in
                guard let username = username else {
                    print("username is nil")
                    return
                }
                UserDefaults.standard.set(username, forKey:AppDelegate.usernameKey)
                self.login(username: username)
            }
        }
        
        audioInp.start(kAudioFormatMPEG4AAC_ELD, 0.1, audioOut)
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
