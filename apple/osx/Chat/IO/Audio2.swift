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
    let engine = AVAudioEngine()

    init()
    {
        let format = engine.inputNode!.inputFormat(forBus: IOBus.input)
        let eqlzr = AVAudioUnitEQ()
        
        eqlzr.globalGain = 24 // increase volume
        engine.attach(eqlzr)
        
        engine.connect(engine.inputNode!, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: eqlzr, format: format)
        engine.connect(eqlzr, to: engine.outputNode, format: format)
        engine.prepare()
    }
    
    func start()
    {
        try! engine.start()
    }
    
    func stop()
    {
        engine.stop()
    }
    
}
