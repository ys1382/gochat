import Foundation

import AudioToolbox
import AVFoundation
import AudioToolbox
import AVFoundation

let kInputBus: UInt32 = 1
let kOutputBus: UInt32 = 0
let sizeofFlag: UInt32 = UInt32(MemoryLayout<UInt32>.size)

class Audio {
    private var desc = AudioComponentDescription()
    private var component: AudioComponent?
    private var unit: AudioUnit?
    private var audioFormat = AudioStreamBasicDescription()
    private var rate: Double = 0.0

    var engine = AVAudioEngine()
    var distortion = AVAudioUnitDistortion()
    var reverb = AVAudioUnitReverb()

    func start() {

        // Setup engine and node instances
        assert(engine.inputNode != nil)
        let input = engine.inputNode!
        let output = engine.outputNode
        let format = input.inputFormat(forBus: 0)

        engine.connect(input, to: output, format: format)

        // Start engine
        do {
            try engine.start()
        } catch {
            assertionFailure("AVAudioEngine start error: \(error)")
        }
    }
}
