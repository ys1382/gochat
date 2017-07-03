//
//  SettingsViewController.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 09/06/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import UIKit
import AVFoundation

class SettingsDismissSegue : UIStoryboardSegue {
    
    override func perform() {
        self.source
            .presentingViewController?
            .dismiss(animated: true, completion:nil)
    }
}

class SettingsViewController : UITableViewController, UITextFieldDelegate {
    
    @IBOutlet weak var textFieldServerIP: UITextField!
    @IBOutlet weak var textFieldVideoWidth: UITextField!
    @IBOutlet weak var textFieldVideoHeight: UITextField!
 
    func updateVideo(_ format: AVCaptureDeviceFormat) {
        AV.shared.defaultVideoDimension = format.dimensions
        
        textFieldVideoWidth.text = String(AV.shared.defaultVideoDimension!.width)
        textFieldVideoHeight.text = String(AV.shared.defaultVideoDimension!.height)
        
        UserDefaults.standard.set(textFieldVideoWidth.text, forKey: Application.kVideoWidth)
        UserDefaults.standard.set(textFieldVideoHeight.text, forKey: Application.kVideoHeight)
        UserDefaults.standard.synchronize()
    }
    
    override func viewDidLoad() {
        textFieldServerIP.text = Backend.address
        
        if let x = AV.shared.defaultVideoDimension {
            textFieldVideoWidth.text = String(x.width)
            textFieldVideoHeight.text = String(x.height)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    @IBAction func textFieldServerIPAction(_ sender: Any) {
        UserDefaults.standard.set(textFieldServerIP.text, forKey: Application.kServerIP)
        UserDefaults.standard.synchronize()
    }
    
    @IBAction func textFieldVideoWidthAction(_ sender: Any) {
        guard let text = textFieldVideoWidth.text else { return }
        guard let width = Int32(text) else { return }
        guard let format = AV.shared.defaultVideoInputDevice?.inputFormat(width: width) else { return }
        
        updateVideo(format)
    }
    
    @IBAction func textFieldVideoHeightAction(_ sender: Any) {
        guard let text = textFieldVideoHeight.text else { return }
        guard let height = Int32(text) else { return }
        guard let format = AV.shared.defaultVideoInputDevice?.inputFormat(height: height) else { return }
        
        updateVideo(format)
    }
}
