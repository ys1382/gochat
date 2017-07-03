//
//  AudioToolbox.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 14/06/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AudioToolbox

class AppleAudioUnit {
    
    let unit: AudioUnit
    
    init(_ unit: AudioUnit) {
        self.unit = unit
    }
    
    convenience init(_ type: OSType, _ subtype: OSType) throws {
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = type
        componentDescription.componentSubType = subtype
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        let component = AudioComponentFindNext(nil, &componentDescription);
        var instance: AudioUnit?
        
        try checkStatus(AudioComponentInstanceNew(component!,
                                                  &instance),
                        "AudioComponentInstanceNew")
        
        self.init(instance!)
    }
    
    func initialize() throws {
        try checkStatus(AudioUnitInitialize(unit),
                        "AudioUnitInitialize")
    }

    func uninitialize() throws {
        try checkStatus(AudioUnitUninitialize(unit),
                        "AudioUnitUninitialize")
    }

    func reset(_ inScope: AudioUnitScope, _ inElement: Int) throws {
        try checkStatus(AudioUnitReset(unit, inScope, AudioUnitElement(inElement)),
                        "AudioUnitReset")
    }

    func start() throws {
        try checkStatus(AudioOutputUnitStart(unit),
                        "AudioOutputUnitStart")
    }

    func stop() throws {
        try checkStatus(AudioOutputUnitStop(unit),
                        "AudioOutputUnitStop")
    }

    func getIOEnabled(_ scope: AudioUnitScope, _ bus: Int) throws -> Bool {
        var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        var res: UInt32 = 0
        try checkStatus(AudioUnitGetProperty(unit,
                                             kAudioOutputUnitProperty_EnableIO,
                                             scope,
                                             UInt32(bus),
                                             &res,
                                             &size),
                        "AudioUnitGetProperty: kAudioOutputUnitProperty_EnableIO")
        return res == 1

    }
    
    func setIOEnabled(_ scope: AudioUnitScope, _ bus: Int, _ value: Bool) throws {
        var valueCopy = value
        #if os(iOS)
            try checkStatus(AudioUnitSetProperty(unit,
                                                 kAudioOutputUnitProperty_EnableIO,
                                                 scope,
                                                 UInt32(bus),
                                                 &valueCopy,
                                                 UInt32(MemoryLayout<UInt32>.size)),
                            "AudioUnitSetProperty: kAudioOutputUnitProperty_EnableIO")
        #endif
    }

    func getFormat(_ scope: AudioUnitScope, _ bus: Int) throws -> AudioStreamBasicDescription {
        var size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var res = AudioStreamBasicDescription()
        try checkStatus(AudioUnitGetProperty(unit,
                                             kAudioUnitProperty_StreamFormat,
                                             scope,
                                             UInt32(bus),
                                             &res,
                                             &size),
                        "AudioUnitGetProperty: kAudioUnitProperty_StreamFormat")
        return res
        
    }
    
    func getFormat(_ scope: AudioUnitScope, _ bus: Int, _ outFormat: inout AudioStreamBasicDescription?) throws {
        outFormat = try getFormat(scope, bus)
    }
    
    func setFormat(_ scope: AudioUnitScope, _ bus: Int, _ value: AudioStreamBasicDescription) throws {
        var valueCopy = value
        try checkStatus(AudioUnitSetProperty(unit,
                                             kAudioUnitProperty_StreamFormat,
                                             scope,
                                             UInt32(bus),
                                             &valueCopy,
                                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                        "AudioUnitSetProperty: kAudioUnitProperty_StreamFormat")
    }

    func setCallback(_ scope: AudioUnitScope, _ bus: Int, _ value: inout AURenderCallbackStruct) throws {
        try checkStatus(AudioUnitSetProperty(unit,
                                             kAudioOutputUnitProperty_SetInputCallback,
                                             scope,
                                             UInt32(bus),
                                             &value,
                                             UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                        "AudioUnitSetProperty: kAudioOutputUnitProperty_SetInputCallback")
    }

    func setRenderer(_ scope: AudioUnitScope, _ bus: Int, _ value: inout AURenderCallbackStruct) throws {
        try checkStatus(AudioUnitSetProperty(unit,
                                             kAudioUnitProperty_SetRenderCallback,
                                             scope,
                                             UInt32(bus),
                                             &value,
                                             UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                        "AudioUnitSetProperty: kAudioUnitProperty_SetRenderCallback")
    }

    func getMatrixVolume(_ scope: AudioUnitScope, _ bus: Int) throws -> Double {
        var res: Float32 = 0
        var size: UInt32 = UInt32(MemoryLayout<Float32>.size)
        try checkStatus(AudioUnitGetProperty(unit,
                                             kMatrixMixerParam_Volume,
                                             scope,
                                             UInt32(bus),
                                             &res,
                                             &size),
                        "AudioUnitGetProperty: kAudioUnitProperty_StreamFormat")
        return Double(res)
    }

    func getMultiChannelVolume(_ scope: AudioUnitScope, _ bus: Int) throws -> Double {
        var res: Float32 = 0
        var size: UInt32 = UInt32(MemoryLayout<Float32>.size)
        try checkStatus(AudioUnitGetProperty(unit,
                                             kMultiChannelMixerParam_Volume,
                                             scope,
                                             UInt32(bus),
                                             &res,
                                             &size),
                        "AudioUnitGetProperty: kAudioUnitProperty_StreamFormat")
        return Double(res)
    }
}
