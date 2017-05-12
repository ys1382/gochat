import Foundation

import AudioToolbox
import AVFoundation
import AudioToolbox
import AVFoundation

class MyPlayer {
    var playerQueue: AudioQueueRef? = nil
    var packetPosition: Int64 = 0
    var numPacketsToRead: UInt32 = 0
    var packetDescs: AudioStreamPacketDescription? = nil
    var isDone: Bool = false
    var recorder: MyRecorder? = nil
}

class MyRecorder {
    var recordQueue: AudioQueueRef? = nil
    var recordPacket: Int64 = 0
    var running: Bool = false
    var player: MyPlayer? = nil
}

class Audio2 {

    let kNumberRecordBuffers = 3

    func MyGetDefaultInputDeviceSampleRate() -> Float64 {
        var deviceID: AudioDeviceID = 0

        var propertyAddress = AudioObjectPropertyAddress()
        propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
        propertyAddress.mElement = 0
        var propertySize: UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
        var error = AudioHardwareServiceGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID)
        if checkError(error) { return -1 }

        propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
        propertyAddress.mElement = 0

        var outSampleRate: Float64 = 0

        propertySize = UInt32(MemoryLayout<Float64>.size)
        error = AudioHardwareServiceGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &outSampleRate)

        return outSampleRate
    }



}
