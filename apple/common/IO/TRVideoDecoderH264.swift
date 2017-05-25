//
//  TRVideoDecoderH264.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 25/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation
import CoreMedia

class TRVideoDecoderH264 : IODataProtocol {
    
    private let output: IOVideoOutputProtocol?
    private var formatDescription : CMFormatDescription?

    init(_ output: IOVideoOutputProtocol?) {
        self.output = output
    }
    
    func process(_ data: [Int: NSData]) {
        
        let h264SPS  = data[IOH264Part.SPS.rawValue]!
        let h264PPS  = data[IOH264Part.PPS.rawValue]!
        let h264Data = data[IOH264Part.Data.rawValue]!
        let h264Time = data[IOH264Part.Time.rawValue]!

        do {
            // format description
            
            var formatDescription: CMFormatDescription?
            
            let parameterSetPointers : [UnsafePointer<UInt8>] = [h264SPS.bytes.assumingMemoryBound(to: UInt8.self),
                                                                 h264PPS.bytes.assumingMemoryBound(to: UInt8.self)]
            let parameterSetSizes : [Int] = [h264SPS.length,
                                             h264PPS.length]
            
            try checkStatus(CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                                2,
                                                                                parameterSetPointers,
                                                                                parameterSetSizes,
                                                                                4,
                                                                                &formatDescription),
                            "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            
            // block buffer
            
            var blockBuffer: CMBlockBuffer?
            let blockBufferData = UnsafeMutablePointer<Int8>.allocate(capacity: h264Data.length)
            blockBufferData.assign(from: h264Data.bytes.assumingMemoryBound(to: Int8.self), count: h264Data.length)

            try checkStatus(CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                               blockBufferData,
                                                               h264Data.length,
                                                               kCFAllocatorDefault,
                                                               nil,
                                                               0,
                                                               h264Data.length,
                                                               0,
                                                               &blockBuffer), "createReadonlyBlockBuffer")
            
            // timing info
            
            let timingInfo = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: 1)
            timingInfo[0] = CMSampleTimingInfo(h264Time)

            // sample buffer
            
            var sampleBuffer : CMSampleBuffer?
            try checkStatus(CMSampleBufferCreateReady(kCFAllocatorDefault,
                                                      blockBuffer,
                                                      formatDescription,
                                                      1,
                                                      1,
                                                      timingInfo,
                                                      0,
                                                      nil,
                                                      &sampleBuffer), "CMSampleBufferCreateReady failed")
            
            // output
            
            output?.process(sampleBuffer!)
        }
        catch {
            logIOError(error.localizedDescription)
        }
    }
    
}
