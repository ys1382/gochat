//
//  UI.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 30/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Typedefs
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if os(iOS)
    import UIKit
    typealias AppleView = UIView
    typealias AppleColor = UIColor
#else
    import Cocoa
    typealias AppleView = NSView
    typealias AppleColor = NSColor
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interface
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension AppleView {
    
    var theLayer: CALayer {
        get {
            #if os(iOS)
            return layer
            #else
            if layer == nil {
                layer = makeBackingLayer()
            }
            return layer!
            #endif
        }
    }

    @IBInspectable var cornerRadius: CGFloat {
        get {
            return theLayer.cornerRadius
        }
        set {
            theLayer.cornerRadius = newValue
            theLayer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidth: CGFloat {
        get {
            return theLayer.borderWidth
        }
        set {
            theLayer.borderWidth = newValue
        }
    }
    
    #if os(iOS)
    @IBInspectable var borderColor:UIColor? {
        get {
            return AppleColor(cgColor: theLayer.borderColor!)
        }
        set {
            theLayer.borderColor = newValue?.cgColor
        }
    }
    #else
    @IBInspectable var borderColor:NSColor? {
        get {
            return AppleColor(cgColor: theLayer.borderColor!)
        }
        set {
            theLayer.borderColor = newValue?.cgColor
        }
    }
    #endif
    
    #if os(OSX)
    @IBInspectable var backgroundColor: NSColor? {
        get {
            if theLayer.backgroundColor != nil {
                return AppleColor(cgColor: theLayer.backgroundColor!)
            }
            else {
                return nil
            }
        }
        set {
            theLayer.backgroundColor = newValue?.cgColor
        }
    }
    #endif
}
