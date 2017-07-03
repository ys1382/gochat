
import Foundation
import CoreMedia
import Fabric
import Crashlytics

class Application : AppleApplicationDelegate {

    static let kCompressedPlayback = false
    static let kUncompressedPlayback = false
    
    static let kServerIP = "kServerIP"
    static let kVideoWidth = "kVideoWidth"
    static let kVideoHeight = "kVideoHeight"

    var playback: IOSessionProtocol?
    
    override init() {

        // start time
        
        _ = HostTimeInfo.shared
        
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
        
        // playback testing
        
        var playback: IOSessionProtocol?

        checkIO {
            
            if Application.kCompressedPlayback {
                playback = try AV.shared.audioCompressedPlayback()
            }
            
            if Application.kUncompressedPlayback {
                playback = try AV.shared.audioUncompressedPlayback()
            }
            
            try playback?.start()
        }
        
        self.playback = playback
    }
}
