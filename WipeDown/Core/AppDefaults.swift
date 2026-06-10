//
//  AppDefaults.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 04.06.2026.
//

import Foundation

enum AppDefaults {
    static let dimScreen = true
    static let lockKeyboard = true
    static let adjustKeyboardBacklight = true
    static let keyboardBrightness = 0.0
    static let holdDuration = 1.0
    static let safetyDuration = 120.0
    static let unlockCombination = UnlockCombination.shifts.rawValue
    static let showMenuBarIcon = false
    static let openSettingsOnLaunch = true

    enum Keys {
        static let dimScreen = "dimScreen"
        static let lockKeyboard = "lockKeyboard"
        static let adjustKeyboardBacklight = "adjustKeyboardBacklight"
        static let keyboardBrightness = "keyboardBrightness"
        static let holdDuration = "holdDuration"
        static let safetyDuration = "safetyDuration"
        static let unlockCombination = "selectedCombination"
        static let startAtLogin = "startAtLogin"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let openSettingsOnLaunch = "openSettingsOnLaunch"
    }

    static func register() {
        let defaults: [String: Any] = [
            Keys.dimScreen: dimScreen,
            Keys.lockKeyboard: lockKeyboard,
            Keys.adjustKeyboardBacklight: adjustKeyboardBacklight,
            Keys.keyboardBrightness: keyboardBrightness,
            Keys.holdDuration: holdDuration,
            Keys.safetyDuration: safetyDuration,
            Keys.unlockCombination: unlockCombination,
            Keys.showMenuBarIcon: showMenuBarIcon,
            Keys.openSettingsOnLaunch: openSettingsOnLaunch
        ]
        UserDefaults.standard.register(defaults: defaults)
    }
}
