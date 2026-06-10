//
//  DisplayBrightnessController.swift
//  WipeDown
//
//  Created by Antigravity on 06.10.2026.
//

import AppKit
import Foundation

class DisplayBrightnessController {
    static let shared = DisplayBrightnessController()
    
    private var setBrightnessFunc: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?
    private var getBrightnessFunc: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var originalBrightness: Float?
    
    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            print("WipeDown: Failed to load DisplayServices dynamically")
            return
        }
        
        if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightnessFunc = unsafeBitCast(setSym, to: (@convention(c) (CGDirectDisplayID, Float) -> Int32).self)
        }
        if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightnessFunc = unsafeBitCast(getSym, to: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32).self)
        }
    }
    
    func getBrightness() -> Float? {
        guard let getFunc = getBrightnessFunc else { return nil }
        var level: Float = 0.0
        let result = getFunc(CGMainDisplayID(), &level)
        return result == 0 ? level : nil
    }
    
    func setBrightness(_ level: Float) {
        guard let setFunc = setBrightnessFunc else { return }
        _ = setFunc(CGMainDisplayID(), level)
    }
    
    func dimDisplay(targetBrightness: Float) {
        guard let current = getBrightness() else {
            print("WipeDown: Could not read display brightness")
            return
        }
        originalBrightness = current
        print("WipeDown: Saved original screen brightness: \(current) -> Dimming to \(targetBrightness)")
        
        setBrightness(targetBrightness)
    }
    
    func restoreDisplay() {
        guard let original = originalBrightness else {
            print("WipeDown: No original screen brightness saved, skipping restore")
            return
        }
        setBrightness(original)
        print("WipeDown: Restored screen brightness to \(original)")
        originalBrightness = nil
    }
}
