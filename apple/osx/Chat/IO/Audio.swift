import Foundation
import AVFoundation

class Audio : IOProtocol {
    let engineI = AVAudioEngine()
    let engineO = AVAudioEngine()
    let player = AVAudioPlayerNode()

    init() {
        let format = engineI.inputNode!.inputFormat(forBus: IOBus.input)
        let node = AVAudioMixerNode()
        
        engineI.attach(node)
        engineO.attach(player)
        
        node.installTap(onBus: IOBus.input,
                        bufferSize: 4096,
                        format: format,
                        block:
        { (buffer: AVAudioPCMBuffer, time: AVAudioTime) in
            
            let buffer_serialized = buffer.serialize()
            let buffer_deserialized = AVAudioPCMBuffer.deserialize(buffer_serialized, format)

            print("audio \(AVAudioTime.seconds(forHostTime: time.hostTime))")
            
            self.player.scheduleBuffer(buffer_deserialized, completionHandler: nil)
        })
        
        engineI.connect(engineI.inputNode!, to: node, format: format)
        engineI.prepare()
        
        engineO.connect(player, to: engineO.outputNode, format: format)
        engineO.prepare()
    }
    
    func start() {
        try! engineI.start()
        try! engineO.start()

        player.play()
    }
    
    func stop() {
        engineI.stop()
        engineO.stop()
    }
}
