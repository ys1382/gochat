import Foundation
import AVFoundation

class Audio {
    
    let inp = TRAudioInput()
    let out = TRAudioOutputBroadcast([TRAudioOutputSerializer(TRAudioOutput()), TRNetworkAudioOutput()])

    func start() {
        inp.start(kAudioFormatMPEG4AAC_ELD, 0.1, out)
    }
    
    func stop() {
        inp.stop()
        out.stop()
    }
}
