//
//  LockManager.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import SwiftUI

// MARK: - Core Definition & Stored Properties

final class LockManager {
    static let shared = LockManager()
    
    var store: WipeDownStore?
    
    var windows: [OverlayWindow] = []
    var pressedKeys = Set<UInt16>()
    var unlockTimer: Timer?
    var safetyTimer: DispatchSourceTimer?
    var eventTap: CFMachPort?
    var eventTapSource: CFRunLoopSource?
    var localEventMonitor: Any?
    var touchBarController: LockTouchBarController?
    var notificationTokens: [NSObjectProtocol] = []
    var isStopping = false
    var lastTimerTick: Date?
    var safetyEndsAt: Date?
    
    var originalPresentationOptions: NSApplication.PresentationOptions = []
    
    let keyCodeEsc: UInt16 = 53
    let keyCodeReturn: UInt16 = 36
    
    private init() {
        installLifecycleObservers()
    }
}

// MARK: - Lock & Unlock Control

extension LockManager {
    func startWipeDown(store: WipeDownStore) {
        self.store = store
        
        guard !store.state.isLocked else { return }

        let shouldLockKeyboard = store.state.lockKeyboard

        if shouldLockKeyboard {
            guard keyboardInterceptionPermissionGranted() else {
                store.send(.lockStartFailed(String(localized: .inputMonitoringPermissionError), isPermissionError: true))
                requestKeyboardInterceptionPermission()
                return
            }
        }

        store.send(.lockStarted)
        pressedKeys.removeAll()

        if shouldLockKeyboard {
            guard startKeyboardInterception() else {
                store.send(.lockStartFailed(String(localized: .keyboardLockStartFailedError)))
                return
            }

            startTouchBarLock()
        }

        startSafetyTimer()
        
        originalPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableAppleMenu,
            .disableForceQuit,
            .disableSessionTermination
        ]
        
        if store.state.dimScreen {
            DisplayBrightnessController.shared.dimDisplay(targetBrightness: physicalDisplayBrightness(for: WipeDownFeature.State.defaultScreenBrightness))
        }
        
        if store.state.lockSettings.adjustKeyboardBacklight {
            KeyboardBrightnessController.shared.dimKeyboard(targetBrightness: Float(store.state.lockSettings.keyboardBrightness))
        }
        
        NSCursor.hide()
        
        showOverlayWindows(for: store)
    }
    
    func stopWipeDown() {
        guard let store = store, store.state.isLocked, !isStopping else { return }
        let shouldRestoreDisplay = store.state.dimScreen
        let shouldRestoreKeyboard = store.state.lockSettings.adjustKeyboardBacklight
        isStopping = true
        store.send(.lockStopped)
        
        stopUnlockTimer()
        stopSafetyTimer()
        stopKeyboardInterception()
        stopTouchBarLock()
        
        closeOverlayWindows()
        
        NSApp.presentationOptions = originalPresentationOptions
        
        if shouldRestoreDisplay {
            DisplayBrightnessController.shared.restoreDisplay()
        }
        if shouldRestoreKeyboard {
            KeyboardBrightnessController.shared.restoreKeyboard()
        }
        
        NSCursor.unhide()
        
        isStopping = false
    }
    
    func cleanupBeforeTermination() {
        if store?.state.isLocked == true {
            stopWipeDown()
        } else {
            stopKeyboardInterception()
            stopTouchBarLock()
            stopSafetyTimer()
            NSCursor.unhide()
        }
    }
}

// MARK: - Keyboard Interception & Event Handling

extension LockManager {
    private func handleKeyDown(keyCode: UInt16) {
        guard store?.state.isLocked == true else { return }
        
        pressedKeys.insert(keyCode)
        logUnlockKeyEvent(action: "down", keyCode: keyCode)
        updateUnlockState()
    }
    
    private func handleKeyUp(keyCode: UInt16) {
        guard store?.state.isLocked == true else { return }
        pressedKeys.remove(keyCode)
        logUnlockKeyEvent(action: "up", keyCode: keyCode)
        updateUnlockState()
    }

    private func handleFlagsChanged(keyCode: UInt16, shiftPressed: Bool) {
        guard store?.state.isLocked == true else { return }

        switch keyCode {
        case 56, 60:
            if shiftPressed {
                pressedKeys.insert(keyCode)
            } else {
                pressedKeys.remove(56)
                pressedKeys.remove(60)
            }
        default:
            break
        }

        updateUnlockState()
    }
    
    private func updateUnlockState() {
        let (key1, key2) = store?.state.selectedCombination.keyCodes ?? (keyCodeEsc, keyCodeReturn)
        let isUnlockCombinationPressed = pressedKeys.contains(key1) && pressedKeys.contains(key2)
        
        if isUnlockCombinationPressed {
            if let store = store, store.state.holdDuration <= 0.0 {
                stopWipeDown()
            } else {
                startUnlockTimer()
            }
        } else {
            stopUnlockTimer()
        }
    }
    
    private func logUnlockKeyEvent(action: String, keyCode: UInt16) {
        guard let store = store else { return }
        let (key1, key2) = store.state.selectedCombination.keyCodes
        guard keyCode == key1 || keyCode == key2 else { return }
        
        print("WipeDown: unlock key \(action): \(keyCode), pressed: \(pressedKeys.sorted())")
    }
    
    private func startKeyboardInterception() -> Bool {
        stopKeyboardInterception()
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]) { [weak self] event in
            switch event.type {
            case .keyDown:
                self?.handleKeyDown(keyCode: event.keyCode)
            case .keyUp:
                self?.handleKeyUp(keyCode: event.keyCode)
            case .flagsChanged:
                self?.handleFlagsChanged(keyCode: event.keyCode, shiftPressed: event.modifierFlags.contains(.shift))
            default:
                break
            }
            return nil
        }
        
        let mask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << 14)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return nil }
                let manager = Unmanaged<LockManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleTappedEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            print("WipeDown: Could not create keyboard event tap. Check Input Monitoring permissions.")
            stopKeyboardInterception()
            return false
        }
        
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let eventTapSource = eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }
    
    private func stopKeyboardInterception() {
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let eventTapSource = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        
        eventTapSource = nil
        eventTap = nil
        pressedKeys.removeAll()
    }
    
    private func handleTappedEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard store?.state.isLocked == true else {
            return Unmanaged.passUnretained(event)
        }
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return nil
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        
        switch type {
        case .keyDown:
            handleKeyDown(keyCode: keyCode)
        case .keyUp:
            handleKeyUp(keyCode: keyCode)
        case .flagsChanged:
            handleFlagsChanged(keyCode: keyCode, shiftPressed: event.flags.contains(.maskShift))
        default:
            break
        }
        
        return nil
    }
    
    private func keyboardInterceptionPermissionGranted() -> Bool {
        AXIsProcessTrusted()
    }

    private func requestKeyboardInterceptionPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Timers

extension LockManager {
    private func startUnlockTimer() {
        guard unlockTimer == nil else { return }
        guard let store = self.store else { return }
        
        if store.state.holdDuration <= 0.0 {
            stopWipeDown()
            return
        }
        
        lastTimerTick = Date()
        
        unlockTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let store = self.store else { return }
            
            guard let lastTick = self.lastTimerTick else {
                self.lastTimerTick = Date()
                return
            }
            
            let now = Date()
            let timePassed = now.timeIntervalSince(lastTick)
            self.lastTimerTick = now
            
            let increment = timePassed / store.state.holdDuration
            let newProgress = min(store.state.unlockProgress + increment, 1.0)
            
            DispatchQueue.main.async {
                store.send(.setUnlockProgress(newProgress))
                if newProgress >= 1.0 {
                    self.stopWipeDown()
                }
            }
        }
    }
    
    private func stopUnlockTimer() {
        unlockTimer?.invalidate()
        unlockTimer = nil
        lastTimerTick = nil
        
        DispatchQueue.main.async {
            self.store?.send(.resetUnlockProgress)
        }
    }
    
    private func startSafetyTimer() {
        stopSafetyTimer()
        
        guard let store = store, store.state.safetyDuration > 0.0 else { return }
        safetyEndsAt = Date().addingTimeInterval(store.state.safetyDuration)
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self, let store = self.store, let safetyEndsAt = self.safetyEndsAt else { return }
            
            let remaining = max(0.0, safetyEndsAt.timeIntervalSinceNow)
            store.send(.setRemainingSafetyTime(remaining))
            if remaining <= 0.0 {
                self.stopWipeDown()
            }
        }
        safetyTimer = timer
        timer.resume()
    }
    
    private func stopSafetyTimer() {
        safetyTimer?.cancel()
        safetyTimer = nil
        safetyEndsAt = nil
    }
}

// MARK: - Lifecycle Observers

extension LockManager {
    private func installLifecycleObservers() {
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        notificationTokens.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupBeforeTermination()
        })
        
        notificationTokens.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildOverlayWindowsIfLocked()
        })
        
        notificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopWipeDown()
        })
        
        notificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopWipeDown()
        })
    }
    
    private func rebuildOverlayWindowsIfLocked() {
        guard let store = store, store.state.isLocked, !isStopping else { return }

        showOverlayWindows(for: store)
    }
}

// MARK: - Overlay Windows Management

extension LockManager {
    private func makeOverlayWindow(for screen: NSScreen, store: WipeDownStore) -> OverlayWindow {
        let window = OverlayWindow(screen: screen)
        let contentView = NSHostingView(rootView: UnlockOverlayView(store: store))
        window.contentView = contentView
        
        window.onKeyDown = { [weak self] event in
            self?.handleKeyDown(keyCode: event.keyCode)
        }
        window.onKeyUp = { [weak self] event in
            self?.handleKeyUp(keyCode: event.keyCode)
        }
        window.onFlagsChanged = { [weak self] event in
            self?.handleFlagsChanged(keyCode: event.keyCode, shiftPressed: event.modifierFlags.contains(.shift))
        }

        return window
    }

    private func showOverlayWindows(for store: WipeDownStore) {
        closeOverlayWindows()
        NSApp.activate(ignoringOtherApps: true)

        windows = NSScreen.screens.map { makeOverlayWindow(for: $0, store: store) }
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func closeOverlayWindows() {
        closeWindows(&windows)
    }

    private func closeWindows<Window: NSWindow>(_ windows: inout [Window]) {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }
    
    private func physicalDisplayBrightness(for overlayBrightness: Double) -> Float {
        Float(max(0.08, overlayBrightness))
    }
}

// MARK: - Touch Bar Control

extension LockManager {
    private func startTouchBarLock() {
        touchBarController = LockTouchBarController()
        touchBarController?.start()
    }
    
    private func stopTouchBarLock() {
        touchBarController?.stop()
        touchBarController = nil
    }
}

// MARK: - Testing Controls

extension LockManager {
    func testScreenDim(
        configuration: WipeDownFeature.TestOverlayConfiguration,
        completion: @escaping () -> Void
    ) {
        let endsAt = Date().addingTimeInterval(3.0)
        var testWindows: [OverlayWindow] = []

        let originalOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableAppleMenu,
            .disableForceQuit
        ]

        DisplayBrightnessController.shared.dimDisplay(
            targetBrightness: physicalDisplayBrightness(for: WipeDownFeature.State.defaultScreenBrightness)
        )
        NSCursor.hide()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = TestDimOverlayView(configuration: configuration, endsAt: endsAt)
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            testWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.closeWindows(&testWindows)
            DisplayBrightnessController.shared.restoreDisplay()
            NSApp.presentationOptions = originalOptions
            NSCursor.unhide()

            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func testKeyboardBlock() {
        let endsAt = Date().addingTimeInterval(3.0)
        var testWindows: [OverlayWindow] = []

        let originalOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableAppleMenu,
            .disableForceQuit
        ]
        NSCursor.hide()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = TestBlockOverlayView(endsAt: endsAt)
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            testWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.closeWindows(&testWindows)
            NSApp.presentationOptions = originalOptions
            NSCursor.unhide()
        }
    }

    func testKeyboardBacklight(
        targetBrightness: Float,
        completion: @escaping () -> Void
    ) {
        let endsAt = Date().addingTimeInterval(3.0)
        var testWindows: [OverlayWindow] = []

        let originalOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableAppleMenu,
            .disableForceQuit
        ]

        KeyboardBrightnessController.shared.dimKeyboard(targetBrightness: targetBrightness)
        NSCursor.hide()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = TestKeyboardBacklightOverlayView(endsAt: endsAt)
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            testWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.closeWindows(&testWindows)
            KeyboardBrightnessController.shared.restoreKeyboard()
            NSApp.presentationOptions = originalOptions
            NSCursor.unhide()

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
