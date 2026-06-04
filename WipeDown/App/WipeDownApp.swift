//
//  WipeDownApp.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI
import AppKit

@main
struct WipeDownApp: App {
    @NSApplicationDelegateAdaptor(WipeDownAppDelegate.self) private var appDelegate
    @StateObject private var store: WipeDownStore
    
    init() {
        AppDefaults.register()
        
        let store = WipeDownStore(
            initialState: WipeDownFeature.State(),
            reducer: WipeDownFeature.reducer()
        )
        _store = StateObject(wrappedValue: store)
        appDelegate.store = store

        AppVisibilityController.shared.apply(showMenuBarIcon: store.state.showMenuBarIcon)

        if store.state.openSettingsOnLaunch || !store.state.showMenuBarIcon {
            DispatchQueue.main.async {
                store.send(.preferencesButtonTapped(store))
            }
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: .menuSettings)) {
                    store.send(.preferencesButtonTapped(store))
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        MenuBarExtra(
            isInserted: store.binding(
                get: \.showMenuBarIcon,
                send: { .appSettings(.setShowMenuBarIcon($0)) }
            )
        ) {
            Button(String(localized: .lockForCleaning)) {
                store.send(.startButtonTapped(store))
            }
            .keyboardShortcut("l", modifiers: [.command, .control])
            
            Button(String(localized: .menuPreferences)) {
                store.send(.preferencesButtonTapped(store))
            }
            .keyboardShortcut(",", modifiers: [.command])
            
            Divider()
            
            Button(String(localized: .menuQuitWipeDown)) {
                store.send(.quitButtonTapped)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            Image(systemName: "wand.and.stars")
        }
    }
}

final class WipeDownAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: WipeDownStore?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let store else { return true }

        if !flag || !store.state.showMenuBarIcon {
            store.send(.preferencesButtonTapped(store))
        }

        return true
    }
}

// MARK: - PreferencesWindowController
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    private weak var store: WipeDownStore?
    
    var isWindowOpen: Bool { window != nil }
    
    func show(store: WipeDownStore) {
        self.store = store
        
        // If window already exists, bring it to front
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = PreferencesView(store: store)
        let hostingView = NSHostingView(rootView: view)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 730),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        win.minSize = NSSize(width: 480, height: 600)
        
        win.title = String(localized: .appName)
        win.titlebarAppearsTransparent = false
        win.backgroundColor = NSColor(resource: .windowBackground)
        win.isOpaque = true
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self

        self.window = win
        
        // Refresh visibility now that the window is open
        AppVisibilityController.shared.apply(showMenuBarIcon: store.state.showMenuBarIcon)
        
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Release the window reference when closed to free resources
        self.window = nil
        
        // Refresh visibility now that the window is closed
        if let store = store {
            AppVisibilityController.shared.apply(showMenuBarIcon: store.state.showMenuBarIcon)
        }
    }
}
