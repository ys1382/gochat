//
//  MainViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 02/06/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Cocoa
import AVFoundation

class ChatViewController : NSViewController {
    
    @IBOutlet weak var textFieldServerIP: NSTextField!
    @IBOutlet weak var textFieldVideoWidth: NSTextField!
    @IBOutlet weak var textFieldVideoHeight: NSTextField!
    
    override func viewDidLoad() {
        textFieldServerIP.stringValue = Backend.address
        
        if let x = AV.shared.defaultVideoDimention {
            textFieldVideoWidth.stringValue = String(x.width)
            textFieldVideoHeight.stringValue = String(x.height)
        }
    }
    
    @IBAction func btnRestartAction(_ sender: Any) {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        exit(0)
    }
   
    @IBAction func textFieldServerIPAction(_ sender: Any) {
        UserDefaults.standard.set(textFieldServerIP.stringValue, forKey: AppDelegate.kServerIP)
    }
    
    @IBAction func textFieldVideoWidthAction(_ sender: Any) {
        guard let dimention = AVCaptureDevice.chatVideoDevice()?.dimentions else { return }
        guard var width = Int32(textFieldVideoWidth.stringValue) else { return }

        if width > AVCaptureDevice.chatVideoDevice()!.dimentions.width {
            width = AVCaptureDevice.chatVideoDevice()!.dimentions.width
        }
        
        AV.shared.defaultVideoDimention?.height = width * dimention.height / dimention.width
        AV.shared.defaultVideoDimention?.width = width
        
        textFieldVideoWidth.stringValue = String(AV.shared.defaultVideoDimention!.width)
        textFieldVideoHeight.stringValue = String(AV.shared.defaultVideoDimention!.height)

        UserDefaults.standard.set(textFieldVideoWidth.stringValue, forKey: AppDelegate.kVideoWidth)
        UserDefaults.standard.set(textFieldVideoHeight.stringValue, forKey: AppDelegate.kVideoHeight)
    }
    
    @IBAction func textFieldVideoHeightAction(_ sender: Any) {
        guard let dimention = AVCaptureDevice.chatVideoDevice()?.dimentions else { return }
        guard var height = Int32(textFieldVideoHeight.stringValue) else { return }
        
        if height > AVCaptureDevice.chatVideoDevice()!.dimentions.height {
            height = AVCaptureDevice.chatVideoDevice()!.dimentions.height
        }

        AV.shared.defaultVideoDimention?.width = height * dimention.width / dimention.height
        AV.shared.defaultVideoDimention?.height = height

        textFieldVideoWidth.stringValue = String(AV.shared.defaultVideoDimention!.width)
        textFieldVideoHeight.stringValue = String(AV.shared.defaultVideoDimention!.height)

        UserDefaults.standard.set(textFieldVideoWidth.stringValue, forKey: AppDelegate.kVideoWidth)
        UserDefaults.standard.set(textFieldVideoHeight.stringValue, forKey: AppDelegate.kVideoHeight)
    }
}
