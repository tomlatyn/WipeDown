//
//  OverlayWindow.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit

final class OverlayWindow: NSWindow {
    var onKeyDown: ((NSEvent) -> Void)?
    var onKeyUp: ((NSEvent) -> Void)?
    var onFlagsChanged: ((NSEvent) -> Void)?
    
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // CGShieldingWindowLevel() is the highest level used for full screen blockers/screensavers
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        self.backgroundColor = .black
        self.alphaValue = 1.0
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.hidesOnDeactivate = false
        self.sharingType = .none
        self.animationBehavior = .none
        
        // Ensure it fills the screen perfectly
        self.setFrame(screen.frame, display: true)
        self.isReleasedWhenClosed = false
    }
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        makeFirstResponder(self)
    }
    
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.defaultItemIdentifiers = []
        return touchBar
    }
    
    override func keyDown(with event: NSEvent) {
        if let onKeyDown = onKeyDown {
            onKeyDown(event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        if let onKeyUp = onKeyUp {
            onKeyUp(event)
        } else {
            super.keyUp(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if let onFlagsChanged = onFlagsChanged {
            onFlagsChanged(event)
        } else {
            super.flagsChanged(with: event)
        }
    }
}
