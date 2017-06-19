//
//  VideoOutput.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 06/06/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation

class VideoOutput : VideoOutputProtocol {
    
    let layer: AVSampleBufferDisplayLayer
    var format: CMFormatDescription?
    
    init(_ layer: AVSampleBufferDisplayLayer) {
        self.layer = layer
    }
    
    func printStatus() {
        if layer.status == .failed {
            logIO("AVQueuedSampleBufferRenderingStatus failed")
        }
        if let error = layer.error {
            logIO(error.localizedDescription)
        }
        if !layer.isReadyForMoreMediaData {
            logIO("Video layer not ready for more media data")
        }
    }

    func process(_ data: CMSampleBuffer) {
        assert_av_output_queue()
        
        let dataFormat = CMSampleBufferGetFormatDescription(data)
        
        if CMFormatDescriptionEqual(format, dataFormat) == false {
            layer.flush()
        }
        
        format = dataFormat
        
        dispatch_sync_on_main {
            if self.layer.isReadyForMoreMediaData && self.layer.status != .failed {
                self.layer.enqueue(data)
            }
            else {
                self.printStatus()
                self.layer.flush()
            }
        }
    }
    
}
