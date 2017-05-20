// todo: add h264 encoding/decoding from https://github.com/shogo4405/lf.swift/tree/master/Sources/Media

import Cocoa
import AVFoundation

class Video:
        NSObject,
        AVCaptureVideoDataOutputSampleBufferDelegate,
        AVCaptureAudioDataOutputSampleBufferDelegate
{
    var callback: ((CMSampleBuffer)->())?
    var captureSession = AVCaptureSession()

    func start() {
        NotificationCenter.default.addObserver(
            forName: .AVSampleBufferDisplayLayerFailedToDecode,
            object: nil,
            queue: nil,
            using: failureNotification)

        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSessionPresetLow
        self.captureSession.commitConfiguration()
        captureSession.startRunning()

        let videoCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if (self.captureSession.canAddInput(videoDeviceInput) == true) {
                self.captureSession.addInput(videoDeviceInput)
            }

            let videoDataOutput = AVCaptureVideoDataOutput()
            let videoQueue = DispatchQueue(label: "videoQueue")

            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (self.captureSession.canAddOutput(videoDataOutput) == true) {
                self.captureSession.addOutput(videoDataOutput)
            }
            
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return AVCaptureVideoPreviewLayer(session: self.captureSession)
    }

    func failureNotification(notification: Notification) {
        print("failureNotification" + notification.description)
    }

    lazy var networkLayer: AVSampleBufferDisplayLayer = {
        var layer = AVSampleBufferDisplayLayer()
        return layer
    }()

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        print("video \(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))")
        callback?(sampleBuffer.copy()!)
    }
}

extension CMSampleBuffer {
    func copy() -> CMSampleBuffer? {

        let formatDescriptionIn = CMSampleBufferGetFormatDescription(self)!
        guard let formatDescriptionOut = formatDescriptionIn.copy() else {
            return nil
        }

        var count: CMItemCount = 1
        var timingInfoIn = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(self, count, &timingInfoIn, &count)
        var timingInfoOut = timingInfoIn.copy()

        if CMFormatDescriptionGetMediaType(formatDescriptionOut) != kCMMediaType_Video {
            print("did not handle format description type \(CMFormatDescriptionGetMediaType(formatDescriptionOut))")
            return nil
        }

        guard let pixelBufferIn : CVPixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            print("could not get image buffer")
            return nil
        }
        let pixelBufferOut = pixelBufferIn.copy()

        var sampleBufferOut: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            pixelBufferOut,
            formatDescriptionOut,
            &timingInfoOut,
            &sampleBufferOut)

        if checkError(status) { return nil }
        return sampleBufferOut
    }
}

extension CMFormatDescription {
    func copy() -> CMFormatDescription? {
        let extensions = CMFormatDescriptionGetExtensions(self)
        let mediaType = CMFormatDescriptionGetMediaType(self)

        var formatOut: CMFormatDescription?
        var status: OSStatus
        switch mediaType {
        case kCMMediaType_Audio:
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(self)
            status = CMAudioFormatDescriptionCreate(
                nil,
                asbd!,
                0,
                nil,
                0,
                nil,
                extensions,
                &formatOut)
        case kCMMediaType_Video:
            let codecType = CMFormatDescriptionGetMediaSubType(self)
            let dimensions = CMVideoFormatDescriptionGetDimensions(self)
            status = CMVideoFormatDescriptionCreate(
                nil,
                codecType,
                dimensions.width,
                dimensions.height,
                extensions,
                &formatOut)
        default:
            status = noErr
            print("did not handle format description media type \(mediaType)")
        }
        if checkError(status) { return nil }
        return formatOut
    }
}

extension CMSampleTimingInfo {
    func copy() -> CMSampleTimingInfo {
        let durationIn = self.duration
        let presentationIn = self.presentationTimeStamp
        let decodeIn = kCMTimeInvalid
        return CMSampleTimingInfo(duration: durationIn, presentationTimeStamp: presentationIn, decodeTimeStamp: decodeIn)
    }

    static func serializeTime(_ cmTime: CMTime) throws -> Time {
        return try Time.Builder()
                .setValue(cmTime.value)
                .setScale(cmTime.timescale)
                .setFlags(cmTime.flags.rawValue)
                .setEpoch(cmTime.epoch)
                .build()
    }

    static func deserializeTime(_ time: Time) -> CMTime {
        return CMTime(
            value: time.value,
            timescale: time.scale,
            flags: CMTimeFlags(rawValue: time.flags),
            epoch: time.epoch)
    }

    func serialize() throws -> Timestamp {
        let duration = try CMSampleTimingInfo.serializeTime(self.duration)
        let presentation = try CMSampleTimingInfo.serializeTime(self.presentationTimeStamp)
        return try Timestamp.Builder()
            .setDuration(duration)
            .setPresentation(presentation)
            .build()
    }

    static func deserialize(timestamp: Timestamp) -> CMSampleTimingInfo? {
        let duration = deserializeTime(timestamp.duration)
        let presentation = deserializeTime(timestamp.presentation)
        return CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentation,
            decodeTimeStamp: kCMTimeInvalid)
    }
}

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")
/*
        do {
            let s = try self.serialize()
            let d = CVPixelBuffer.deserialize(s)
            return d!
        } catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
*/
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

    func serialize() throws -> Image {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        let attachments = CVBufferGetAttachments(self, .shouldPropagate)
        let dict = attachments as! [String: String]

        CVPixelBufferLockBaseAddress(self, .readOnly)

        let umrp = CVPixelBufferGetBaseAddress(self)!
        let size = CVPixelBufferGetDataSize(self)
        let data = Data(bytesNoCopy: umrp, count: Int(size), deallocator: Data.Deallocator.free)

        let imageBuilder = Image.Builder()
            .setWidth(Int64(width))
            .setHeight(Int64(height))
            .setFormat(format)
            .setAttachments(dict)
            .setData(data)

        CVPixelBufferUnlockBaseAddress(self, .readOnly)

        return try imageBuilder.build()
    }

    static func deserialize(_ image: Image) -> CVPixelBuffer? {
        var pixelBufferOut : CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            Int(image.width),
            Int(image.height),
            image.format,
            nil,
            &pixelBufferOut)

        CVPixelBufferLockBaseAddress(pixelBufferOut!, CVPixelBufferLockFlags(rawValue: 0))

        memcpy(
            CVPixelBufferGetBaseAddress(pixelBufferOut!),
            (image.data as NSData).bytes,
            image.data.count)

        CVPixelBufferUnlockBaseAddress(pixelBufferOut!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBufferOut
    }
}
