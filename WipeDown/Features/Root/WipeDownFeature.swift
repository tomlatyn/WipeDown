//
//  WipeDownFeature.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import Foundation
import SwiftUI

typealias WipeDownStore = Store<WipeDownFeature.State, WipeDownFeature.Action>

enum WipeDownFeature {
    typealias TestOverlayConfiguration = LockSettingsFeature.TestOverlayConfiguration

    struct State {
        static let defaultScreenBrightness = LockSettingsFeature.State.defaultScreenBrightness

        var preferences = PreferencesFeature.State()
        var lockSettings: LockSettingsFeature.State
        var appSettings: AppSettingsFeature.State
        var about = AboutFeature.State()

        var isLocked = false
        var unlockProgress = 0.0
        var remainingSafetyTime: TimeInterval = 0.0
        var statusMessage: String?
        var needsInputMonitoringPermission = false

        init(defaults: UserDefaults = .standard, loginItemService: AppLoginItemServicing = AppLoginItemService.shared) {
            lockSettings = LockSettingsFeature.State(defaults: defaults)
            appSettings = AppSettingsFeature.State(defaults: defaults, loginItemService: loginItemService)
        }

        var dimScreen: Bool {
            get { lockSettings.dimScreen }
            set { lockSettings.dimScreen = newValue }
        }

        var lockKeyboard: Bool {
            get { lockSettings.lockKeyboard }
            set { lockSettings.lockKeyboard = newValue }
        }

        var holdDuration: Double {
            get { lockSettings.holdDuration }
            set { lockSettings.holdDuration = newValue }
        }

        var safetyDuration: Double {
            get { lockSettings.safetyDuration }
            set { lockSettings.safetyDuration = newValue }
        }

        var selectedCombination: UnlockCombination {
            get { lockSettings.selectedCombination }
            set { lockSettings.selectedCombination = newValue }
        }

        var showMenuBarIcon: Bool {
            get { appSettings.showMenuBarIcon }
            set { appSettings.showMenuBarIcon = newValue }
        }

        var openSettingsOnLaunch: Bool {
            get { appSettings.openSettingsOnLaunch }
            set { appSettings.openSettingsOnLaunch = newValue }
        }

        var holdDurationText: String {
            lockSettings.holdDurationText
        }

        var unlockPrompt: String {
            lockSettings.unlockPrompt
        }

        var overlayOpacity: Double {
            lockSettings.overlayOpacity
        }

        var safetyDurationText: String {
            lockSettings.safetyDurationText
        }

        var remainingSafetyTimeText: String {
            LockSettingsFeature.State.formattedDuration(remainingSafetyTime)
        }
    }

    enum Action {
        case startButtonTapped(WipeDownStore)
        case stopRequested
        case preferencesButtonTapped(WipeDownStore)
        case quitButtonTapped

        case preferences(PreferencesFeature.Action)
        case lockSettings(LockSettingsFeature.Action)
        case appSettings(AppSettingsFeature.Action)
        case about(AboutFeature.Action)

        case lockStarted
        case lockStartFailed(String, isPermissionError: Bool = false)
        case lockStopped
        case clearStatusMessage
        case setUnlockProgress(Double)
        case resetUnlockProgress
        case setRemainingSafetyTime(TimeInterval)
    }

    static func reducer(
        lockManager: LockManager = .shared,
        preferencesWindow: PreferencesWindowController = .shared,
        loginItemService: AppLoginItemServicing = AppLoginItemService.shared,
        appVisibility: AppVisibilityControlling = AppVisibilityController.shared,
        workspace: NSWorkspace = .shared,
        defaults: UserDefaults = .standard
    ) -> (inout State, Action) -> Effect<Action> {
        let preferencesReducer = PreferencesFeature.reducer()
        let lockSettingsReducer = LockSettingsFeature.reducer(lockManager: lockManager, defaults: defaults)
        let appSettingsReducer = AppSettingsFeature.reducer(
            loginItemService: loginItemService,
            appVisibility: appVisibility,
            defaults: defaults
        )
        let aboutReducer = AboutFeature.reducer(workspace: workspace)

        return { state, action in
            switch action {
            case let .startButtonTapped(store):
                state.statusMessage = nil
                return .fireAndForget {
                    lockManager.startWipeDown(store: store)
                }

            case .stopRequested:
                return .fireAndForget {
                    lockManager.stopWipeDown()
                }

            case let .preferencesButtonTapped(store):
                return .fireAndForget {
                    preferencesWindow.show(store: store)
                }

            case .quitButtonTapped:
                return .fireAndForget {
                    lockManager.cleanupBeforeTermination()
                    NSApplication.shared.terminate(nil)
                }

            case let .preferences(action):
                return preferencesReducer(&state.preferences, action)
                    .map(Action.preferences)

            case let .lockSettings(action):
                return lockSettingsReducer(&state.lockSettings, action)
                    .map(Action.lockSettings)

            case let .appSettings(action):
                switch action {
                case .setStartAtLogin:
                    state.statusMessage = nil
                case let .startAtLoginUpdateFailed(_, message):
                    state.statusMessage = String(localized: .startAtLoginUpdateFailedFormat(message))
                default:
                    break
                }

                return appSettingsReducer(&state.appSettings, action)
                    .map(Action.appSettings)

            case let .about(action):
                return aboutReducer(&state.about, action)
                    .map(Action.about)

            case .lockStarted:
                state.isLocked = true
                state.unlockProgress = 0.0
                state.remainingSafetyTime = state.safetyDuration
                state.statusMessage = nil
                return .none

            case let .lockStartFailed(message, isPermissionError):
                state.isLocked = false
                state.remainingSafetyTime = 0.0
                state.statusMessage = message
                state.needsInputMonitoringPermission = isPermissionError
                return .none

            case .lockStopped:
                state.isLocked = false
                state.unlockProgress = 0.0
                state.remainingSafetyTime = 0.0
                state.needsInputMonitoringPermission = false
                return .none

            case .clearStatusMessage:
                state.statusMessage = nil
                state.needsInputMonitoringPermission = false
                return .none

            case let .setUnlockProgress(progress):
                state.unlockProgress = progress
                return .none

            case .resetUnlockProgress:
                withAnimation(.easeOut(duration: 0.2)) {
                    state.unlockProgress = 0.0
                }
                return .none

            case let .setRemainingSafetyTime(remaining):
                state.remainingSafetyTime = remaining
                return .none
            }
        }
    }
}
