
import Foundation
import CoreMedia
import Fabric
import Crashlytics

class Application : AppleApplicationDelegate {
    
    static let kServerIP = "kServerIP"
    static let kVideoWidth = "kVideoWidth"
    static let kVideoHeight = "kVideoHeight"

    override init() {

        // crash on unhandled exceptions
        
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true]);

        // fabric
        
        Fabric.with([Crashlytics.self])
        
        // server IP
        
        let serverIP = UserDefaults.standard.string(forKey: Application.kServerIP)
        
        if (serverIP != nil) {
            Backend.address = serverIP!
        }
        
        // video dimension
        
        let videoWidth = UserDefaults.standard.string(forKey: Application.kVideoWidth)
        let videoHeight = UserDefaults.standard.string(forKey: Application.kVideoHeight)
        
        if videoWidth != nil && videoHeight != nil {
            AV.shared.defaultVideoDimension = CMVideoDimensions(width: Int32(videoWidth!)!,
                                                                height: Int32(videoHeight!)!)
        }
    }
}
