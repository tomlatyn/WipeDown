//
//  LockManager.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import IOKit.hid
import IOKit.hidsystem
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
    var hidManager: IOHIDManager?
    var localEventMonitor: Any?
    var touchBarController: LockTouchBarController?
    var notificationTokens: [NSObjectProtocol] = []
    var isStopping = false
    var isKeyboardBlockTestActive = false
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

    private func handleFlagsChanged(keyCode: UInt16, modifierFlagsRawValue: UInt64) {
        guard store?.state.isLocked == true else { return }

        switch keyCode {
        case 56:
            if modifierFlagsRawValue & UInt64(NX_DEVICELSHIFTKEYMASK) != 0 {
                pressedKeys.insert(keyCode)
            } else {
                pressedKeys.remove(keyCode)
            }
        case 60:
            if modifierFlagsRawValue & UInt64(NX_DEVICERSHIFTKEYMASK) != 0 {
                pressedKeys.insert(keyCode)
            } else {
                pressedKeys.remove(keyCode)
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

    private var shouldBlockKeyboardInput: Bool {
        store?.state.isLocked == true || isKeyboardBlockTestActive
    }
    
    private func startKeyboardInterception() -> Bool {
        stopKeyboardInterception()
        let hidCaptureStarted = startHIDKeyboardCapture()
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]) { [weak self] event in
            switch event.type {
            case .keyDown:
                self?.handleKeyDown(keyCode: event.keyCode)
            case .keyUp:
                self?.handleKeyUp(keyCode: event.keyCode)
            case .flagsChanged:
                self?.handleFlagsChanged(keyCode: event.keyCode, modifierFlagsRawValue: UInt64(event.modifierFlags.rawValue))
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
            if !hidCaptureStarted {
                stopKeyboardInterception()
                return false
            }
            return true
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
        stopHIDKeyboardCapture()
        isKeyboardBlockTestActive = false
        pressedKeys.removeAll()
    }
    
    private func handleTappedEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard shouldBlockKeyboardInput else {
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
            handleFlagsChanged(keyCode: keyCode, modifierFlagsRawValue: event.flags.rawValue)
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

    private func startHIDKeyboardCapture() -> Bool {
        guard hidManager == nil else { return true }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keypad
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_SystemControl
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_Consumer,
                kIOHIDDeviceUsageKey as String: kHIDUsage_Csmr_ConsumerControl
            ]
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let manager = Unmanaged<LockManager>.fromOpaque(context).takeUnretainedValue()
            manager.handleHIDValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            print("WipeDown: Could not seize HID keyboard devices. IOReturn: \(result)")
            return false
        }

        hidManager = manager
        return true
    }

    private func stopHIDKeyboardCapture() {
        guard let manager = hidManager else { return }

        IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
    }

    private func handleHIDValue(_ value: IOHIDValue) {
        guard shouldBlockKeyboardInput else { return }

        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad else { return }
        guard let keyCode = macVirtualKeyCode(forHIDUsage: IOHIDElementGetUsage(element)) else { return }

        if IOHIDValueGetIntegerValue(value) == 0 {
            handleKeyUp(keyCode: keyCode)
        } else {
            handleKeyDown(keyCode: keyCode)
        }
    }

    private func macVirtualKeyCode(forHIDUsage usage: UInt32) -> UInt16? {
        switch usage {
        case 0x28: return keyCodeReturn
        case 0x29: return keyCodeEsc
        case 0x2C: return 49
        case 0xE1: return 56
        case 0xE5: return 60
        default: return nil
        }
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
            self?.handleFlagsChanged(keyCode: event.keyCode, modifierFlagsRawValue: UInt64(event.modifierFlags.rawValue))
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
        let keyboardInterceptionStarted = startKeyboardInterception()
        isKeyboardBlockTestActive = keyboardInterceptionStarted

        if !keyboardInterceptionStarted {
            print("WipeDown: Keyboard block test could not start interception.")
        }

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
            self.stopKeyboardInterception()
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
