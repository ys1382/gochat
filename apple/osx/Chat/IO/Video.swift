// todo: add h264 encoding/decoding from https://github.com/shogo4405/lf.swift/tree/master/Sources/Media

import Cocoa
import AVFoundation

class Video:
    NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate,
    IOProtocol
{
    var callback: ((CMSampleBuffer)->())?
    var captureSession = AVCaptureSession()

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func start()
    {
        NotificationCenter.default.addObserver(forName: .AVSampleBufferDisplayLayerFailedToDecode,
                                               object: nil,
                                               queue: nil,
                                               using: failureNotification)
    }
    
    func stop()
    {
        
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Setup
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func setup(session: AVCaptureSession)
    {
        self.captureSession = session
        
        let videoCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
        
        do
        {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            // inputs
            
            if (captureSession.canAddInput(videoDeviceInput) == true)
            {
                captureSession.addInput(videoDeviceInput)
            }
            
            // outputs
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            let videoQueue = DispatchQueue(label: "videoQueue")

            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (captureSession.canAddOutput(videoDataOutput) == true)
            {
                captureSession.addOutput(videoDataOutput)
            }
            
        }
        catch let error as NSError
        {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Accessing internals
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer
    {
         return AVCaptureVideoPreviewLayer(session: self.captureSession)
    }

    func failureNotification(notification: Notification)
    {
        print("failureNotification" + notification.description)
    }

    lazy var networkLayer: AVSampleBufferDisplayLayer =
    {
        var layer = AVSampleBufferDisplayLayer()
        return layer
    }()

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Capture handlers
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!)
    {
        print("video \(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))")
        callback?(sampleBuffer.copy()!)
    }


}

