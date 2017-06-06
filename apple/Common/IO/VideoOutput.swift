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
        
        DispatchQueue.main.sync {
            if layer.isReadyForMoreMediaData {
                layer.enqueue(data)
            }
            else {
                printStatus()
                layer.flush()
            }
        }

    }
    
}
