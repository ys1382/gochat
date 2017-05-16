//
//  CVPixelBuffer.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
        
        var pixelBufferCopy : CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &pixelBufferCopy)
        
        guard let pixelBufferOut = pixelBufferCopy else { fatalError() }
        
        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(pixelBufferOut, CVPixelBufferLockFlags(rawValue: 0))
        
        memcpy(
            CVPixelBufferGetBaseAddress(pixelBufferOut),
            CVPixelBufferGetBaseAddress(self),
            CVPixelBufferGetDataSize(self))
        
        CVPixelBufferUnlockBaseAddress(pixelBufferOut, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, .readOnly)
        
        let attachments = CVBufferGetAttachments(self, .shouldPropagate)
        var dict = attachments as! [String: AnyObject]
        dict["MetadataDictionary"] = nil // because not needed (probably)
        CVBufferSetAttachments(pixelBufferOut, dict as CFDictionary, .shouldPropagate)
        
        return pixelBufferOut
    }
}
