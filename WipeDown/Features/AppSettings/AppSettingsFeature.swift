//
//  AppSettingsFeature.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import Foundation
import ServiceManagement

enum AppSettingsFeature {
    struct State {
        var startAtLogin: Bool
        var showMenuBarIcon: Bool
        var openSettingsOnLaunch: Bool

        init(defaults: UserDefaults = .standard, loginItemService: AppLoginItemServicing = AppLoginItemService.shared) {
            startAtLogin = defaults.object(forKey: AppDefaults.Keys.startAtLogin) as? Bool ?? loginItemService.isEnabled
            showMenuBarIcon = defaults.bool(forKey: AppDefaults.Keys.showMenuBarIcon)
            openSettingsOnLaunch = defaults.bool(forKey: AppDefaults.Keys.openSettingsOnLaunch)

            if !showMenuBarIcon {
                openSettingsOnLaunch = true
                defaults.set(true, forKey: AppDefaults.Keys.openSettingsOnLaunch)
            }
        }
    }

    enum Action {
        case setStartAtLogin(Bool)
        case startAtLoginUpdateFailed(previousValue: Bool, message: String)
        case setShowMenuBarIcon(Bool)
        case setOpenSettingsOnLaunch(Bool)
    }

    static func reducer(
        loginItemService: AppLoginItemServicing = AppLoginItemService.shared,
        appVisibility: AppVisibilityControlling = AppVisibilityController.shared,
        defaults: UserDefaults = .standard
    ) -> (inout State, Action) -> Effect<Action> {
        { state, action in
            switch action {
            case let .setStartAtLogin(value):
                let previousValue = state.startAtLogin
                state.startAtLogin = value
                defaults.set(value, forKey: AppDefaults.Keys.startAtLogin)

                return Effect { send in
                    do {
                        try loginItemService.setEnabled(value)
                    } catch {
                        send(.startAtLoginUpdateFailed(previousValue: previousValue, message: error.localizedDescription))
                    }
                }

            case let .startAtLoginUpdateFailed(previousValue, _):
                state.startAtLogin = previousValue
                defaults.set(previousValue, forKey: AppDefaults.Keys.startAtLogin)
                return .none

            case let .setShowMenuBarIcon(value):
                state.showMenuBarIcon = value
                defaults.set(value, forKey: AppDefaults.Keys.showMenuBarIcon)

                if !value {
                    state.openSettingsOnLaunch = true
                    defaults.set(true, forKey: AppDefaults.Keys.openSettingsOnLaunch)
                }

                return .fireAndForget {
                    appVisibility.apply(showMenuBarIcon: value)
                }

            case let .setOpenSettingsOnLaunch(value):
                guard state.showMenuBarIcon else {
                    state.openSettingsOnLaunch = true
                    defaults.set(true, forKey: AppDefaults.Keys.openSettingsOnLaunch)
                    return .none
                }

                state.openSettingsOnLaunch = value
                defaults.set(value, forKey: AppDefaults.Keys.openSettingsOnLaunch)
                return .none
            }
        }
    }
}



protocol AppLoginItemServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

struct AppLoginItemService: AppLoginItemServicing {
    static let shared = AppLoginItemService()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

protocol AppVisibilityControlling {
    func apply(showMenuBarIcon: Bool)
}

struct AppVisibilityController: AppVisibilityControlling {
    static let shared = AppVisibilityController()

    func apply(showMenuBarIcon: Bool) {
        DispatchQueue.main.async {
            let isWindowOpen = PreferencesWindowController.shared.isWindowOpen
            NSApp.setActivationPolicy((showMenuBarIcon && !isWindowOpen) ? .accessory : .regular)
        }
    }
}
