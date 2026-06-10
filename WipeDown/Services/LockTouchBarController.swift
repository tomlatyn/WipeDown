//
//  LockTouchBarController.swift
//  WipeDown
//
//  Created by Antigravity on 06.10.2026.
//

import AppKit

class LockTouchBarController: NSObject, NSTouchBarDelegate {
    private let touchBar = NSTouchBar()
    private let itemIdentifier = NSTouchBarItem.Identifier("com.latyn.WipeDown.lockedTouchBar")
    private let systemTrayIdentifier = NSTouchBarItem.Identifier("com.latyn.WipeDown.lockedSystemTray")
    private var isPresented = false
    
    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [itemIdentifier]
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.latyn.WipeDown.lockedTouchBar")
    }
    
    func start() {
        guard !isPresented else { return }
        
        presentSystemModalTouchBar()
        isPresented = true
    }
    
    func stop() {
        guard isPresented else { return }
        
        dismissSystemModalTouchBar()
        isPresented = false
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == itemIdentifier else { return nil }
        
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        item.view = view
        return item
    }
    
    private func presentSystemModalTouchBar() {
        let selector = NSSelectorFromString("presentSystemModalFunctionBar:systemTrayItemIdentifier:")
        guard NSTouchBar.responds(to: selector) else {
            print("WipeDown: System modal Touch Bar API is not available")
            return
        }
        
        typealias PresentFunction = @convention(c) (AnyClass, Selector, NSTouchBar, NSTouchBarItem.Identifier) -> Void
        let implementation = NSTouchBar.method(for: selector)
        let function = unsafeBitCast(implementation, to: PresentFunction.self)
        function(NSTouchBar.self, selector, touchBar, systemTrayIdentifier)
    }
    
    private func dismissSystemModalTouchBar() {
        let selector = NSSelectorFromString("dismissSystemModalFunctionBar:")
        guard NSTouchBar.responds(to: selector) else { return }
        
        typealias DismissFunction = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
        let implementation = NSTouchBar.method(for: selector)
        let function = unsafeBitCast(implementation, to: DismissFunction.self)
        function(NSTouchBar.self, selector, touchBar)
    }
}
