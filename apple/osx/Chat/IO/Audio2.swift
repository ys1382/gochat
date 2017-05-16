//
//  Audio2.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation
import AVFoundation

class Audio2 : IOProtocol
{
    let engineI = AVAudioEngine()
    let engineO = AVAudioEngine()
    let player = AVAudioPlayerNode()

    init()
    {
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

            self.player.scheduleBuffer(buffer_deserialized, completionHandler: nil)
        })
        
        engineI.connect(engineI.inputNode!, to: node, format: format)
        engineI.prepare()
        
        engineO.connect(player, to: engineO.outputNode, format: format)
        engineO.prepare()
    }
    
    func start()
    {
        try! engineI.start()
        try! engineO.start()

        player.play()
    }
    
    func stop()
    {
        engineI.stop()
        engineO.stop()
    }
    
}
