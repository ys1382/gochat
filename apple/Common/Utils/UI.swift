//
//  UI.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 30/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// View
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// View controller
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func instantiateViewController<T>(_ storyboard: AppleStoryboard) -> T {
    #if os(iOS)
    return storyboard.instantiateViewController(withIdentifier: typeName(T.self)) as! T
    #else
    return storyboard.instantiateController(withIdentifier: typeName(T.self)) as! T
    #endif
}

