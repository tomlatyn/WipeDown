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

enum UnlockCombination: String, CaseIterable, Identifiable {
    case escReturn = "Esc + Return"
    case shifts = "Left Shift + Right Shift"
    case spaceEsc = "Space + Esc"

    var id: String { rawValue }
    var displayString: String { rawValue }

    var keyCodes: (UInt16, UInt16) {
        switch self {
        case .escReturn: return (53, 36)
        case .shifts: return (56, 60)
        case .spaceEsc: return (49, 53)
        }
    }
}

enum WipeDownFeature {
    struct TestOverlayConfiguration {
        let overlayOpacity: Double
    }

    struct State {
        static let defaultScreenBrightness = 0.1

        var isLocked = false
        var unlockProgress = 0.0
        var remainingSafetyTime: TimeInterval = 0.0
        var statusMessage: String?

        var dimScreen: Bool
        var holdDuration: Double
        var safetyDuration: Double
        var selectedCombination: UnlockCombination

        var isTestingScreenDim = false

        init(defaults: UserDefaults = .standard) {
            dimScreen = defaults.object(forKey: DefaultsKey.dimScreen) as? Bool ?? true
            holdDuration = defaults.object(forKey: DefaultsKey.holdDuration) as? Double ?? 1.0
            safetyDuration = Self.clampedSafetyDuration(defaults.object(forKey: DefaultsKey.safetyDuration) as? Double ?? 300.0)

            if let savedCombination = defaults.string(forKey: DefaultsKey.unlockCombination),
               let combination = UnlockCombination(rawValue: savedCombination) {
                selectedCombination = combination
            } else {
                selectedCombination = .shifts
            }
        }

        var holdDurationText: String {
            holdDuration == 0.0 ? "Instant" : String(format: "%.1f sec", holdDuration)
        }

        var unlockPrompt: String {
            let action = holdDuration == 0.0 ? "Press" : "Hold"
            return "\(action) \(selectedCombination.displayString) to unlock"
        }

        var overlayOpacity: Double {
            dimScreen ? (1.0 - Self.defaultScreenBrightness) : 1.0
        }

        var safetyDurationText: String {
            Self.formattedDuration(safetyDuration)
        }

        var remainingSafetyTimeText: String {
            Self.formattedDuration(remainingSafetyTime)
        }

        static func clampedSafetyDuration(_ value: Double) -> Double {
            min(300.0, max(30.0, value))
        }

        static func formattedDuration(_ seconds: Double) -> String {
            let totalSeconds = Int(seconds.rounded())
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60

            if minutes == 0 {
                return "\(remainingSeconds) sec"
            }

            if remainingSeconds == 0 {
                return "\(minutes) min"
            }

            return "\(minutes) min \(remainingSeconds) sec"
        }
    }

    enum Action {
        case startButtonTapped(WipeDownStore)
        case stopRequested
        case preferencesButtonTapped(WipeDownStore)
        case quitButtonTapped

        case setDimScreen(Bool)
        case setSelectedCombination(UnlockCombination)
        case setHoldDuration(Double)
        case setSafetyDuration(Double)

        case lockStarted
        case lockStartFailed(String)
        case lockStopped
        case setUnlockProgress(Double)
        case resetUnlockProgress
        case setRemainingSafetyTime(TimeInterval)

        case testScreenDimTapped
        case testScreenDimFinished
        case testKeyboardBlockTapped
    }

    static func reducer(
        lockManager: LockManager = .shared,
        preferencesWindow: PreferencesWindowController = .shared,
        defaults: UserDefaults = .standard
    ) -> (inout State, Action) -> Effect<Action> {
        { state, action in
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

            case let .setDimScreen(value):
                state.dimScreen = value
                defaults.set(value, forKey: DefaultsKey.dimScreen)
                return .none

            case let .setSelectedCombination(value):
                state.selectedCombination = value
                defaults.set(value.rawValue, forKey: DefaultsKey.unlockCombination)
                return .none

            case let .setHoldDuration(value):
                state.holdDuration = value
                defaults.set(value, forKey: DefaultsKey.holdDuration)
                return .none

            case let .setSafetyDuration(value):
                let clamped = State.clampedSafetyDuration(value)
                state.safetyDuration = clamped
                defaults.set(clamped, forKey: DefaultsKey.safetyDuration)
                return .none

            case .lockStarted:
                state.isLocked = true
                state.unlockProgress = 0.0
                state.remainingSafetyTime = state.safetyDuration
                state.statusMessage = nil
                return .none

            case let .lockStartFailed(message):
                state.isLocked = false
                state.remainingSafetyTime = 0.0
                state.statusMessage = message
                return .none

            case .lockStopped:
                state.isLocked = false
                state.unlockProgress = 0.0
                state.remainingSafetyTime = 0.0
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

            case .testScreenDimTapped:
                guard !state.isTestingScreenDim else { return .none }
                state.isTestingScreenDim = true
                let configuration = TestOverlayConfiguration(
                    overlayOpacity: state.overlayOpacity
                )
                return Effect { send in
                    lockManager.testScreenDim(configuration: configuration) {
                        send(.testScreenDimFinished)
                    }
                }

            case .testScreenDimFinished:
                state.isTestingScreenDim = false
                return .none

            case .testKeyboardBlockTapped:
                return .fireAndForget {
                    lockManager.testKeyboardBlock()
                }
            }
        }
    }
}

private enum DefaultsKey {
    static let dimScreen = "dimScreen"
    static let holdDuration = "holdDuration"
    static let safetyDuration = "safetyDuration"
    static let unlockCombination = "selectedCombination"
}
