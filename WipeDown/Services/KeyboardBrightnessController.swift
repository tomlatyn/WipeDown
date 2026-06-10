//
//  KeyboardBrightnessController.swift
//  WipeDown
//
//  Created by Antigravity on 06.10.2026.
//

import Foundation

// MARK: - KeyboardBrightnessClientProtocol

@objc private protocol KeyboardBrightnessClientProtocol {
    @discardableResult
    func setBrightness(_ brightness: Float, forKeyboard keyboardID: UInt64) -> Bool
    func brightness(forKeyboard keyboardID: UInt64) -> Float
}

// MARK: - KeyboardBrightnessController

class KeyboardBrightnessController {
    static let shared = KeyboardBrightnessController()
    
    private var brightnessClient: AnyObject?
    private var originalBrightness: Float?
    
    private init() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            print("WipeDown: Failed to load CoreBrightness dynamically")
            return
        }
        
        if let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type {
            brightnessClient = clientClass.init()
        } else {
            print("WipeDown: Failed to get KeyboardBrightnessClient class")
        }
    }
    
    func getBrightness() -> Float? {
        guard let client = brightnessClient else { return nil }
        return client.brightness?(forKeyboard: 1)
    }
    
    func setBrightness(_ level: Float) {
        guard let client = brightnessClient else { return }
        _ = client.setBrightness?(level, forKeyboard: 1)
    }
    
    func dimKeyboard(targetBrightness: Float) {
        guard let current = getBrightness() else {
            print("WipeDown: Could not read keyboard brightness")
            return
        }
        originalBrightness = current
        print("WipeDown: Saved original keyboard brightness: \(current) -> Dimming to \(targetBrightness)")
        
        setBrightness(targetBrightness)
    }
    
    func restoreKeyboard() {
        guard let original = originalBrightness else {
            print("WipeDown: No original keyboard brightness saved, skipping restore")
            return
        }
        setBrightness(original)
        print("WipeDown: Restored keyboard brightness to \(original)")
        originalBrightness = nil
    }
}
