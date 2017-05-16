//
//  IOCapture.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import AVFoundation

class IOCapture : IOProtocol
{
    
    private var session: AVCaptureSession!
    
    init(_ session: AVCaptureSession)
    {
        self.session = session;
    }
    
    func start()
    {
        session.startRunning()
    }
    
    func stop()
    {
        session.stopRunning()
    }
}
