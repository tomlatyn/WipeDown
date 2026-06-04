//
//  LockManager.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import SwiftUI

final class LockManager {
    static let shared = LockManager()
    
    private var windows: [OverlayWindow] = []
    private var pressedKeys = Set<UInt16>()
    private var unlockTimer: Timer?
    private var safetyTimer: DispatchSourceTimer?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var localEventMonitor: Any?
    private var touchBarController: LockTouchBarController?
    private var notificationTokens: [NSObjectProtocol] = []
    private var isStopping = false
    private var lastTimerTick: Date?
    private var safetyEndsAt: Date?
    
    private var originalPresentationOptions: NSApplication.PresentationOptions = []
    
    // Key codes
    private let keyCodeEsc: UInt16 = 53
    private let keyCodeReturn: UInt16 = 36
    
    var store: WipeDownStore?
    
    private init() {
        installLifecycleObservers()
    }
    
    func startWipeDown(store: WipeDownStore) {
        self.store = store
        
        guard !store.state.isLocked else { return }
        
        guard keyboardInterceptionPermissionGranted() else {
            store.send(.lockStartFailed("Allow WipeDown in Input Monitoring before starting the lock."))
            requestKeyboardInterceptionPermission()
            return
        }
        
        store.send(.lockStarted)
        pressedKeys.removeAll()
        
        guard startKeyboardInterception() else {
            store.send(.lockStartFailed("Keyboard lock could not start. Check Input Monitoring permissions."))
            return
        }
        
        startTouchBarLock()
        startSafetyTimer()
        
        // 1. Save original presentation options and set kiosk mode
        originalPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableAppleMenu,
            .disableForceQuit,
            .disableSessionTermination
        ]
        
        // 2. Dim hardware screen if configured
        if store.state.dimScreen {
            DisplayBrightnessController.shared.dimDisplay(targetBrightness: physicalDisplayBrightness(for: WipeDownFeature.State.defaultScreenBrightness))
        }
        
        // 3. Hide cursor
        NSCursor.hide()
        
        // 4. Create full screen overlay windows on all connected screens
        showOverlayWindows(for: store)
    }
    
    func stopWipeDown() {
        guard let store = store, store.state.isLocked, !isStopping else { return }
        let shouldRestoreDisplay = store.state.dimScreen
        isStopping = true
        store.send(.lockStopped)
        
        // 1. Stop timer
        stopUnlockTimer()
        stopSafetyTimer()
        stopKeyboardInterception()
        stopTouchBarLock()
        
        // 2. Close overlay windows
        closeOverlayWindows()
        
        // 3. Restore presentation options
        NSApp.presentationOptions = originalPresentationOptions
        
        // 4. Restore brightness settings
        if shouldRestoreDisplay {
            DisplayBrightnessController.shared.restoreDisplay()
        }
        
        // 5. Show cursor
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
    
    private func startUnlockTimer() {
        guard unlockTimer == nil else { return }
        guard let store = self.store else { return }
        
        if store.state.holdDuration <= 0.0 {
            stopWipeDown()
            return
        }
        
        lastTimerTick = Date()
        
        // Tick every 0.05 seconds for smooth progress updates
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
        CGPreflightListenEventAccess()
    }
    
    private func requestKeyboardInterceptionPermission() {
        _ = CGRequestListenEventAccess()
    }
    
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
    
    private func startTouchBarLock() {
        touchBarController = LockTouchBarController()
        touchBarController?.start()
    }
    
    private func stopTouchBarLock() {
        touchBarController?.stop()
        touchBarController = nil
    }
    
    private func physicalDisplayBrightness(for overlayBrightness: Double) -> Float {
        // Keep the panel lit enough for the unlock instructions and safety timer.
        Float(max(0.08, overlayBrightness))
    }
    
    // MARK: - Testing Controls
    
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
}

// MARK: - Display Dim Test Helper View
private struct TestDimOverlayView: View {
    let configuration: WipeDownFeature.TestOverlayConfiguration
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let countdown = max(0, Int(ceil(endsAt.timeIntervalSince(context.date))))

            ZStack {
                Color.black
                    .opacity(configuration.overlayOpacity)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 24) {
                    ZStack {
                        Image(systemName: "display")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    VStack(spacing: 8) {
                        Text("Display dimming test is active.")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))

                        Text("Ends automatically in \(countdown) sec")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Blocker Test Helper View
private struct TestBlockOverlayView: View {
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let countdown = max(0, Int(ceil(endsAt.timeIntervalSince(context.date))))

            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 24) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.6))

                    Text("Keyboard Block Testing")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    Text("All keypresses are blocked.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))

                    Text("Ends automatically in \(countdown) sec")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - LockTouchBarController
private class LockTouchBarController: NSObject, NSTouchBarDelegate {
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

// MARK: - DisplayBrightnessController
private class DisplayBrightnessController {
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
