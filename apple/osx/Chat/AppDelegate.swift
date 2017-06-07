import Cocoa
import AVFoundation
import Fabric
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static var shared: AppDelegate!
    static let usernameKey = "usernamekey"

    static let kServerIP = "kServerIP"
    static let kVideoWidth = "kVideoWidth"
    static let kVideoHeight = "kVideoHeight"

    func login(username: String) {
        Backend.shared.connect(withUsername: username)
    }

    override init() {
        super.init()
        
        AppDelegate.shared = self
        
        // server IP
        
        let serverIP = UserDefaults.standard.string(forKey: AppDelegate.kServerIP)
        
        if (serverIP != nil) {
            Backend.address = serverIP!
        }
        
        // video dimention
        
        let videoWidth = UserDefaults.standard.string(forKey: AppDelegate.kVideoWidth)
        let videoHeight = UserDefaults.standard.string(forKey: AppDelegate.kVideoHeight)
        
        if videoWidth != nil && videoHeight != nil {
            AV.shared.defaultVideoDimention = CMVideoDimensions(width: Int32(videoWidth!)!,
                                                                height: Int32(videoHeight!)!)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // fabric
        
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        Fabric.with([Crashlytics.self])
        
        // username
            
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
        
        AV.shared.setupDefaultNetworkInputAudio(nil)
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
