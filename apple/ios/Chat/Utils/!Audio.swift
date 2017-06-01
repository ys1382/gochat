
import AVFoundation

class ChatAudioSession : IOSessionProtocol {
    
    func start() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    func stop() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch {
            logIOError(error)
        }
    }
}
