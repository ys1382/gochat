
import AVFoundation

class ChatAudioSession : IOSessionProtocol {
    
    let next: IOSessionProtocol?
    
    convenience init() {
        self.init(nil)
    }
    
    init(_ next: IOSessionProtocol?) {
        self.next = next
    }
    
    func start() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        try AVAudioSession.sharedInstance().setActive(true)
        
        try next?.start()
    }
    
    func stop() {
        next?.stop()
        
//        do {
//            try AVAudioSession.sharedInstance().setActive(false)
//        }
//        catch {
//            logIOError(error)
//        }
    }
}
