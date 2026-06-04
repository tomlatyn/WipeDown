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
    @StateObject private var store: WipeDownStore
    
    init() {
        let store = WipeDownStore(
            initialState: WipeDownFeature.State(),
            reducer: WipeDownFeature.reducer()
        )
        _store = StateObject(wrappedValue: store)
        // Open the preferences window on launch so the user knows the app is running
        DispatchQueue.main.async {
            store.send(.preferencesButtonTapped(store))
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            Button("Start WipeDown") {
                store.send(.startButtonTapped(store))
            }
            .keyboardShortcut("l", modifiers: [.command, .control])
            
            Button("Preferences...") {
                store.send(.preferencesButtonTapped(store))
            }
            .keyboardShortcut(",", modifiers: [.command])
            
            Divider()
            
            Button("Quit WipeDown") {
                store.send(.quitButtonTapped)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            Image(systemName: "lock.shield")
        }
    }
}

// MARK: - PreferencesWindowController
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    
    func show(store: WipeDownStore) {
        // If window already exists, bring it to front
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = PreferencesView(store: store)
        let hostingView = NSHostingView(rootView: view)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        win.minSize = NSSize(width: 420, height: 520)
        win.maxSize = NSSize(width: 800, height: 1000)
        
        win.title = "WipeDown"
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Release the window reference when closed to free resources
        self.window = nil
    }
}
